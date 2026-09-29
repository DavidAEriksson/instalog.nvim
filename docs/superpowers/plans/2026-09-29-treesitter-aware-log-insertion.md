# Tree-sitter-aware Log Insertion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `InstalogNextLine` stub with a single `:InstalogInsert` command that inserts a per-language log statement at a syntactically valid position near the identifier under the cursor, using Tree-sitter to find that position.

**Architecture:** Five focused Lua modules — `config` (defaults + user merge), `print_definitions` (per-language log statement + Tree-sitter node-type lists), `format` (pure string templating), `placement` (the Tree-sitter ancestor walk), `insert` (orchestration + buffer write) — wired together by a thin `instalog.lua` entrypoint and a `plugin/instalog.lua` command registration.

**Tech Stack:** Lua, Neovim's built-in `vim.treesitter` API, `nvim-treesitter` (for parser installation only — not its Lua API), plenary.nvim (testing, already vendored via `tests/minimal_init.lua`).

**Spec:** `docs/superpowers/specs/2026-09-29-treesitter-aware-log-insertion-design.md`

## Global Constraints

- No out-of-the-box languages beyond typescript, javascript, lua, go, python (v1).
- No log-level selection — always the single default `log_statement` per language; the existing `log_level` table is dropped.
- No visual-selection/expression logging — identifier under the cursor only.
- Never fall back to inserting text when no Tree-sitter parser is available or no legal position is found — always `vim.notify` and no-op.
- Config merge strategy is `vim.tbl_deep_extend('force', defaults, user_config)`.
- Per-language `format` override in `print_definitions` takes precedence over the global `format` default; languages without an override use the global default.

## Review Focus

- Cursor on a non-identifier node (punctuation, keyword, whitespace) → `vim.notify` info, no-op, never insert garbage. Covered in Task 4.
- Buffer's filetype is configured in `print_definitions` but its Tree-sitter parser isn't installed/available → `vim.notify` warning, no-op, never fall back to blind insertion. Covered in Task 4.
- Cursor on a top-level statement with no enclosing function/block (e.g. a top-level `const`/`var` in a script) → must still resolve via the top-level `program`/`module`/`chunk`/`source_file` fallback, not error. Covered in Task 3.
- Format template containing an unrecognized placeholder (e.g. `%foo`) → left literal in the output, never a Lua error. Covered in Task 2.
- Per-language `format` override vs. global default resolution — an override must win, and languages without one must still see the global default (easy to get backwards). Covered in Task 1.

---

## File Structure

- Create: `lua/instalog/config.lua` — defaults, `setup()` merge, `get_language_config(filetype)`.
- Modify: `lua/instalog/print_definitions.lua` — full rewrite to the new per-language schema.
- Delete: `lua/instalog/context.lua`, `tests/instalog/context_spec.lua` — superseded by `config.get_language_config`, which owns the same lookup without duplicating it.
- Create: `lua/instalog/format.lua` — template rendering.
- Create: `lua/instalog/placement.lua` — the Tree-sitter ancestor walk.
- Create: `lua/instalog/insert.lua` — orchestration + buffer write.
- Modify: `lua/instalog.lua` — shrinks to `setup()` + `insert_log()` delegating to the modules above.
- Delete: `instalog/instalog.lua` (stray, wrong location, registers the old `InstalogNextLine`).
- Create: `plugin/instalog.lua` — registers `:InstalogInsert` at the conventional load-time location.
- Modify: `tests/minimal_init.lua` — bootstrap `nvim-treesitter` and install the four language parsers needed for tests, following the existing plenary auto-clone pattern.
- Modify: `tests/instalog/instalog_spec.lua` — replace the obsolete `next_line` assertions with `setup()`/delegation tests.
- Create: `tests/instalog/config_spec.lua`, `tests/instalog/format_spec.lua`, `tests/instalog/placement_spec.lua`, `tests/instalog/insert_spec.lua`.
- Modify: `README.md` — document `setup()`, the config schema, and how to add a language.

---

### Task 1: Config module and print_definitions schema overhaul

**Files:**
- Create: `lua/instalog/config.lua`
- Modify: `lua/instalog/print_definitions.lua` (full rewrite)
- Delete: `lua/instalog/context.lua`, `tests/instalog/context_spec.lua`
- Modify: `lua/instalog.lua`
- Modify: `tests/instalog/instalog_spec.lua`
- Test: `tests/instalog/config_spec.lua`

**Interfaces:**
- Produces: `config.setup(user_config)`, `config.get_language_config(filetype) -> table|nil` where the returned table has `log_statement: string`, `format: string`, `block_types: string[]`, `container_types: string[]`. Later tasks (`format`, `placement`, `insert`) consume this return shape directly.

- [ ] **Step 1: Write the failing config tests**

Create `tests/instalog/config_spec.lua`:

```lua
describe("config", function()
  local config = require("instalog.config")

  before_each(function()
    config.setup({})
  end)

  it("returns nil for an unconfigured filetype", function()
    assert.is_nil(config.get_language_config("missing"))
  end)

  it("returns the global format for a language with no override", function()
    local lang = config.get_language_config("lua")
    assert.equals("%file (Line %line): ", lang.format)
  end)

  it("lets a per-language format override the global default", function()
    config.setup({
      print_definitions = {
        go = { format = "%file:%line " },
      },
    })
    local go = config.get_language_config("go")
    assert.equals("%file:%line ", go.format)
    -- other languages are unaffected and still see the global default
    local lua_lang = config.get_language_config("lua")
    assert.equals("%file (Line %line): ", lua_lang.format)
  end)

  it("deep-merges user print_definitions over defaults instead of replacing them", function()
    config.setup({
      print_definitions = {
        go = { log_statement = "log.Println" },
      },
    })
    local go = config.get_language_config("go")
    assert.equals("log.Println", go.log_statement)
    -- block_types/container_types survive the merge since we only overrode log_statement
    assert.is_true(#go.block_types > 0)
  end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `module 'instalog.config' not found`

- [ ] **Step 3: Rewrite print_definitions.lua with the new schema**

Replace the contents of `lua/instalog/print_definitions.lua`:

```lua
return {
  typescript = {
    log_statement = 'console.log',
    block_types = { 'program', 'statement_block', 'class_body' },
    container_types = {
      'function_declaration',
      'method_definition',
      'arrow_function',
      'function_expression',
      'if_statement',
      'for_statement',
      'for_in_statement',
      'while_statement',
    },
  },
  javascript = {
    log_statement = 'console.log',
    block_types = { 'program', 'statement_block', 'class_body' },
    container_types = {
      'function_declaration',
      'method_definition',
      'arrow_function',
      'function_expression',
      'if_statement',
      'for_statement',
      'for_in_statement',
      'while_statement',
    },
  },
  lua = {
    log_statement = 'print',
    block_types = { 'chunk', 'block' },
    container_types = { 'function_declaration', 'local_function' },
  },
  go = {
    log_statement = 'fmt.Println',
    block_types = { 'source_file', 'block' },
    container_types = { 'function_declaration', 'method_declaration', 'for_statement' },
  },
  python = {
    log_statement = 'print',
    block_types = { 'module', 'block' },
    container_types = {
      'function_definition',
      'if_statement',
      'for_statement',
      'while_statement',
      'class_definition',
    },
  },
}
```

These node-type lists are a best-effort default based on each language's public grammar. Task 3 verifies them against real parsers via `placement_spec.lua`; if a name is wrong for the installed grammar version, fix it here (never work around it in `placement.lua`).

- [ ] **Step 4: Write config.lua**

```lua
local M = {}

M.defaults = {
  format = '%file (Line %line): ',
  print_definitions = require('instalog.print_definitions'),
}

M.options = vim.deepcopy(M.defaults)

M.setup = function(user_config)
  M.options = vim.tbl_deep_extend('force', M.defaults, user_config or {})
end

M.get_language_config = function(filetype)
  local lang = M.options.print_definitions[filetype]
  if not lang then
    return nil
  end
  return vim.tbl_extend('force', { format = M.options.format }, lang)
end

return M
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `make test`
Expected: PASS for all `config_spec.lua` cases

- [ ] **Step 6: Delete the superseded context module and its spec**

```bash
git rm lua/instalog/context.lua tests/instalog/context_spec.lua
```

- [ ] **Step 7: Shrink instalog.lua and replace the obsolete instalog_spec.lua**

Replace `lua/instalog.lua`:

```lua
local config = require('instalog.config')

local M = {}

M.setup = function(user_config)
  config.setup(user_config)
end

return M
```

(`insert_log` is added to this module in Task 4 once `insert.lua` exists — leave it out for now.)

Replace `tests/instalog/instalog_spec.lua`:

```lua
describe("instalog.setup", function()
  local instalog = require("instalog")
  local config = require("instalog.config")

  it("delegates to config.setup", function()
    instalog.setup({ format = "%file %line" })
    assert.equals("%file %line", config.options.format)
  end)
end)
```

- [ ] **Step 8: Run the full suite to verify nothing else broke**

Run: `make test`
Expected: PASS — all specs green

- [ ] **Step 9: Commit**

```bash
git add lua/instalog.lua lua/instalog/config.lua lua/instalog/print_definitions.lua tests/instalog/config_spec.lua tests/instalog/instalog_spec.lua
git rm lua/instalog/context.lua tests/instalog/context_spec.lua 2>/dev/null || true
git commit -m "feat(config): add config module and per-language node-type schema"
```

---

### Task 2: format.lua — template rendering

**Files:**
- Create: `lua/instalog/format.lua`
- Test: `tests/instalog/format_spec.lua`

**Interfaces:**
- Consumes: nothing from earlier tasks (pure function).
- Produces: `format.render(template: string, values: table<string,any>) -> string`, where `values` keys match template placeholder names without the `%` (e.g. `{ file = "...", line = 3, var = "x" }` for `"%file (Line %line): "`). Task 4 (`insert.lua`) calls this with `{ file = ..., line = ..., var = ... }`.

- [ ] **Step 1: Write the failing tests**

Create `tests/instalog/format_spec.lua`:

```lua
describe("format.render", function()
  local format = require("instalog.format")

  it("substitutes known placeholders", function()
    local result = format.render("%file (Line %line): ", { file = "test.ts", line = 3 })
    assert.equals("test.ts (Line 3): ", result)
  end)

  it("substitutes a var placeholder alongside file/line", function()
    local result = format.render("%file:%line %var", { file = "a.lua", line = 1, var = "x" })
    assert.equals("a.lua:1 x", result)
  end)

  it("leaves unrecognized placeholders literal instead of erroring", function()
    local result = format.render("%file %foo", { file = "a.go" })
    assert.equals("a.go %foo", result)
  end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `module 'instalog.format' not found`

- [ ] **Step 3: Implement format.lua**

```lua
local M = {}

M.render = function(template, values)
  local result = template:gsub('%%(%a+)', function(key)
    if values[key] ~= nil then
      return tostring(values[key])
    end
    return '%' .. key
  end)
  return result
end

return M
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test`
Expected: PASS for all `format_spec.lua` cases

- [ ] **Step 5: Commit**

```bash
git add lua/instalog/format.lua tests/instalog/format_spec.lua
git commit -m "feat(format): add template renderer for log message format"
```

---

### Task 3: Tree-sitter parser bootstrap and placement.lua

**Files:**
- Modify: `tests/minimal_init.lua`
- Create: `lua/instalog/placement.lua`
- Test: `tests/instalog/placement_spec.lua`

**Interfaces:**
- Consumes: a language config table shaped like `config.get_language_config(...)`'s return value (`block_types`, `container_types`).
- Produces: `placement.find_insertion_point(node, lang_config) -> insert_row, indent_col` (both 0-indexed, matching `nvim_buf_set_lines`/`nvim_win_get_cursor` conventions) or `nil, reason: string` if no position can be determined. Task 4 (`insert.lua`) consumes this signature directly.

- [ ] **Step 1: Bootstrap nvim-treesitter and the four language parsers in minimal_init.lua**

Modify `tests/minimal_init.lua` (append after the existing plenary bootstrap, before `require("plenary.busted")`):

```lua
local treesitter_dir = os.getenv("TREESITTER_DIR") or "/tmp/nvim-treesitter"
if vim.fn.isdirectory(treesitter_dir) == 0 then
  vim.fn.system({ "git", "clone", "https://github.com/nvim-treesitter/nvim-treesitter", treesitter_dir })
end
vim.opt.rtp:append(treesitter_dir)

require("nvim-treesitter.configs").setup({
  ensure_installed = { "typescript", "javascript", "lua", "go", "python" },
  sync_install = true,
})
```

This mirrors the existing plenary auto-clone: parsers are compiled once into `~/.local/share/nvim/site` (or `TREESITTER_DIR`'s parser dir) and reused on subsequent runs. Requires a C compiler (`cc`/`gcc`) on the machine running `make test` — already true for the GitHub Actions `ubuntu-latest` runner and for a normal macOS dev machine with Xcode command line tools.

- [ ] **Step 2: Run make test once to let parsers install (slow the first time)**

Run: `make test`
Expected: Takes noticeably longer the first run (compiling 5 parsers); existing specs still PASS. No new specs yet.

- [ ] **Step 3: Write the failing placement tests**

Create `tests/instalog/placement_spec.lua`. This uses real buffers and real parsers (no mocking) since the whole point of `placement.lua` is correctness against real grammars:

```lua
local placement = require("instalog.placement")
local config = require("instalog.config")

local function set_buffer_lines(lines, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", filetype)
  vim.api.nvim_set_current_buf(buf)
  vim.treesitter.start(buf, filetype)
  return buf
end

describe("placement.find_insertion_point", function()
  before_each(function()
    config.setup({})
  end)

  it("inserts after a top-level statement (typescript)", function()
    local buf = set_buffer_lines({ 'const value = "hello"' }, "typescript")
    -- cursor on "value" (row 0, col 6)
    local node = vim.treesitter.get_node({ bufnr = buf, pos = { 0, 6 } })
    local lang = config.get_language_config("typescript")
    local row, indent = placement.find_insertion_point(node, lang)
    assert.equals(1, row)
    assert.equals("", indent)
  end)

  it("inserts as the first line of a function body when cursor is in the signature (typescript)", function()
    local buf = set_buffer_lines({
      "function myFunc(param) {",
      "}",
    }, "typescript")
    -- cursor on "param" (row 0, col 17)
    local node = vim.treesitter.get_node({ bufnr = buf, pos = { 0, 17 } })
    local lang = config.get_language_config("typescript")
    local row, indent = placement.find_insertion_point(node, lang)
    assert.equals(1, row)
    assert.equals("  ", indent)
  end)

  it("resolves via the top-level fallback when nothing else matches (lua)", function()
    local buf = set_buffer_lines({ 'local value = "hello"' }, "lua")
    local node = vim.treesitter.get_node({ bufnr = buf, pos = { 0, 6 } })
    local lang = config.get_language_config("lua")
    local row, indent = placement.find_insertion_point(node, lang)
    assert.equals(1, row)
    assert.equals("", indent)
  end)
end)
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `module 'instalog.placement' not found`

- [ ] **Step 5: Implement placement.lua**

```lua
local M = {}

local function contains(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

-- Resolves the "body-like" child field of a container node, trying the
-- common field names used across grammars in order.
local function resolve_body_field(node)
  for _, field_name in ipairs({ 'body', 'consequence' }) do
    local field = node:field(field_name)
    if field and field[1] then
      return field[1]
    end
  end
  return nil
end

local function indent_of(bufnr, row)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
  return line:match('^%s*') or ''
end

M.find_insertion_point = function(node, lang_config)
  local bufnr = vim.api.nvim_get_current_buf()
  local current = node

  while current do
    -- Check container_types BEFORE checking the parent-is-a-block rule.
    -- Walking outward from the cursor, if the cursor were already inside
    -- this container's body, an inner ancestor whose parent is a
    -- block_types node would have matched and returned already. So
    -- reaching a container node here always means the cursor is still in
    -- its header/signature, and redirecting into its body is correct.
    if contains(lang_config.container_types, current:type()) then
      local body = resolve_body_field(current)
      if body then
        local body_start_row = body:range()
        local container_start_row = current:range()
        return body_start_row + 1, indent_of(bufnr, container_start_row) .. '  '
      end
    end

    local parent = current:parent()
    if parent and contains(lang_config.block_types, parent:type()) then
      local start_row, _, end_row = current:range()
      return end_row + 1, indent_of(bufnr, start_row)
    end

    current = parent
  end

  return nil, 'no matching block_types or container_types ancestor found'
end

return M
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `make test`
Expected: PASS for all `placement_spec.lua` cases. If a case fails because a grammar's actual node type or field name differs from Task 1's defaults (e.g. `:InspectTree` on the failing buffer shows a different name), fix the entry in `lua/instalog/print_definitions.lua` — never special-case it inside `placement.lua`.

- [ ] **Step 7: Commit**

```bash
git add tests/minimal_init.lua lua/instalog/placement.lua tests/instalog/placement_spec.lua
git commit -m "feat(placement): add treesitter ancestor walk for log insertion point"
```

---

### Task 4: insert.lua orchestration, command wiring, and integration test

**Files:**
- Create: `lua/instalog/insert.lua`
- Modify: `lua/instalog.lua`
- Delete: `instalog/instalog.lua`
- Create: `plugin/instalog.lua`
- Test: `tests/instalog/insert_spec.lua`

**Interfaces:**
- Consumes: `config.get_language_config(filetype)` (Task 1), `format.render(template, values)` (Task 2), `placement.find_insertion_point(node, lang_config)` (Task 3).
- Produces: `insert.insert_log()` (no args, operates on the current buffer/cursor) — bound to `:InstalogInsert`.

- [ ] **Step 1: Write the failing integration tests**

Create `tests/instalog/insert_spec.lua`:

```lua
local insert = require("instalog.insert")
local config = require("instalog.config")

local function set_buffer_lines(lines, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", filetype)
  vim.api.nvim_set_current_buf(buf)
  vim.treesitter.start(buf, filetype)
  return buf
end

describe("insert.insert_log", function()
  before_each(function()
    config.setup({})
  end)

  it("inserts a console.log line after a top-level declaration (typescript)", function()
    local buf = set_buffer_lines({ 'const value = "hello"' }, "typescript")
    vim.api.nvim_win_set_cursor(0, { 1, 6 }) -- on "value"

    insert.insert_log()

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.equals('const value = "hello"', lines[1])
    assert.matches('^console%.log%(".*%(Line 2%): ", value%)$', lines[2])
  end)

  it("notifies and does not insert when the cursor is not on an identifier", function()
    local buf = set_buffer_lines({ 'const value = "hello"' }, "typescript")
    vim.api.nvim_win_set_cursor(0, { 1, 12 }) -- on the "=" sign

    local notified = false
    local original_notify = vim.notify
    vim.notify = function(...) notified = true end

    insert.insert_log()
    vim.notify = original_notify

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.equals(1, #lines)
    assert.is_true(notified)
  end)

  it("notifies and does not insert for an unconfigured filetype", function()
    local buf = set_buffer_lines({ "print('hi')" }, "markdown")
    vim.api.nvim_win_set_cursor(0, { 1, 1 })

    local notified = false
    local original_notify = vim.notify
    vim.notify = function(...) notified = true end

    insert.insert_log()
    vim.notify = original_notify

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.equals(1, #lines)
    assert.is_true(notified)
  end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `module 'instalog.insert' not found`

- [ ] **Step 3: Implement insert.lua**

```lua
local config = require('instalog.config')
local placement = require('instalog.placement')
local format = require('instalog.format')

local M = {}

M.insert_log = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype
  local lang_config = config.get_language_config(filetype)

  if not lang_config then
    vim.notify('Instalog: filetype "' .. filetype .. '" is not configured. See print_definitions.', vim.log.levels.WARN)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { cursor[1] - 1, cursor[2] } })

  if not node then
    vim.notify('Instalog: no Tree-sitter parser available for filetype "' .. filetype .. '".', vim.log.levels.WARN)
    return
  end

  if node:type() ~= 'identifier' then
    vim.notify('Instalog: place the cursor on an identifier.', vim.log.levels.INFO)
    return
  end

  local var_name = vim.treesitter.get_node_text(node, bufnr)
  local insert_row, indent = placement.find_insertion_point(node, lang_config)

  if not insert_row then
    vim.notify('Instalog: ' .. indent, vim.log.levels.WARN)
    return
  end

  local file_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':~:.')
  local message = format.render(lang_config.format, {
    file = file_path,
    line = insert_row + 1,
    var = var_name,
  })

  local log_line = indent .. lang_config.log_statement .. '(' .. string.format('%q', message) .. ', ' .. var_name .. ')'
  vim.api.nvim_buf_set_lines(bufnr, insert_row, insert_row, false, { log_line })
end

return M
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test`
Expected: PASS for all `insert_spec.lua` cases

- [ ] **Step 5: Wire the command**

Delete the stray registration file:

```bash
git rm instalog/instalog.lua
```

Create `plugin/instalog.lua`:

```lua
vim.api.nvim_create_user_command('InstalogInsert', function()
  require('instalog').insert_log()
end, {})
```

Modify `lua/instalog.lua` to expose `insert_log`:

```lua
local config = require('instalog.config')
local insert = require('instalog.insert')

local M = {}

M.setup = function(user_config)
  config.setup(user_config)
end

M.insert_log = function()
  insert.insert_log()
end

return M
```

- [ ] **Step 6: Run the full suite**

Run: `make test`
Expected: PASS — all specs green

- [ ] **Step 7: Commit**

```bash
git add lua/instalog/insert.lua lua/instalog.lua plugin/instalog.lua tests/instalog/insert_spec.lua
git rm instalog/instalog.lua 2>/dev/null || true
git commit -m "feat(insert): wire InstalogInsert command to treesitter-aware insertion"
```

---

### Task 5: README documentation

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: the final config schema from Tasks 1–4 (nothing new to produce; this task is documentation only).

- [ ] **Step 1: Document setup, the command, and the config schema**

Replace `README.md`'s body (keep the existing header/badges) with:

```markdown
## Usage

Call `:InstalogInsert` with the cursor on an identifier to insert a
context-aware log statement at the nearest syntactically valid position:

```lua
require('instalog').setup({})
```

```ts
const value = "hello"
//     ^ cursor here, run :InstalogInsert
console.log("~/dir/test.ts (Line 2): ", value)
```

## Supported languages

Out of the box: `typescript`, `javascript`, `lua`, `go`, `python`.

## Configuration

```lua
require('instalog').setup({
  format = '%file (Line %line): ',  -- global default; %file, %line, %var
  print_definitions = {
    go = {
      log_statement = 'fmt.Println',
      format = '%file:%line ',       -- optional per-language override
      block_types = { 'source_file', 'block' },
      container_types = { 'function_declaration', 'method_declaration', 'for_statement' },
    },
  },
})
```

To add or extend a language, add an entry under `print_definitions` with:
- `log_statement` — the function to call (e.g. `console.log`, `fmt.Println`).
- `block_types` — Tree-sitter node types whose children form a statement sequence.
- `container_types` — Tree-sitter node types with a body (functions, loops, etc.) where the cursor may be in a header/signature.

Use `:InspectTree` (built into Neovim) on a sample buffer to find the exact node type names for your language.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs(readme): document setup, command, and config schema"
```

---

## Self-Review Notes

- **Spec coverage:** architecture (Task 1 + 4), placement algorithm (Task 3), data flow (Task 4), config schema (Task 1), error handling — unsupported filetype/no parser/non-identifier/exhausted walk (Task 3 + 4), testing plan — format/placement/insert specs (Tasks 2–4). Command rename and misregistration fix: Task 4. All spec sections have an owning task.
- **Type consistency:** `config.get_language_config` return shape (`log_statement`, `format`, `block_types`, `container_types`) is defined in Task 1 and consumed identically in Tasks 3 and 4. `placement.find_insertion_point(node, lang_config) -> row, indent|nil, reason` is defined in Task 3 and consumed identically in Task 4. `format.render(template, values)` is defined in Task 2 and consumed identically in Task 4.
- **Review Focus:** all five items have an owning task and an explicit test, listed above.
