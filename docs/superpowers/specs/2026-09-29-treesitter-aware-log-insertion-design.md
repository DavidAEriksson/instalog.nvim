# Instalog.nvim: Tree-sitter-aware log insertion

Status: approved
Date: 2026-09-29

## Purpose

Instalog.nvim exposes a single user command that inserts a context-aware
log statement into the active buffer, using the identifier under the
cursor as the value to log. The insertion point must be syntactically
valid for the buffer's language, which requires Tree-sitter to locate a
legal statement position rather than blindly inserting on the next line.

Example (TypeScript):

```ts
const value = "hello"
//     ^ cursor here, user runs :InstalogInsert
console.log("~/dir/test.ts (Line 2): ", value)
```

Example showing why naive "insert on next line" is wrong — placing the
log statement between a function's signature and its opening brace would
break syntax, so it must go inside the function body instead:

```ts
function myFunc(param: string)
//                ^ cursor here, user runs :InstalogInsert
{
  console.log("~/dir/test.ts (Line 3): ", param) // inserted as first line of body
}
```

The log statement's function (`console.log`, `fmt.Println`, `print`, ...)
and message format are per-language and user-configurable, since they
differ by language and by user preference.

## Non-goals (v1)

- Visual-selection / arbitrary-expression logging (cursor-word identifier
  only).
- Log-level selection (warn/error/debug) — always uses a single default
  log function per language. `print_definitions.lua`'s existing
  `log_level` table is dropped from v1 scope; can return later as a
  command argument.
- New out-of-the-box languages beyond typescript/javascript, lua, go,
  python.

## Architecture

Five focused Lua modules replace today's flat
`lua/instalog.lua` + `context.lua` + `print_definitions.lua`:

- **`instalog/config.lua`** — merges user config over built-in defaults
  (global + per-language `print_definitions`), via
  `vim.tbl_deep_extend('force', defaults, user_config)` (same strategy
  `instalog.lua` already uses today, deepened to cover nested fields).
- **`instalog/print_definitions.lua`** — built-in defaults for
  typescript/javascript, lua, go, python: `log_statement`, `block_types`,
  `container_types`, and default message `format`.
- **`instalog/placement.lua`** — the Tree-sitter walk (below). Given a
  buffer and cursor position, returns `{ insert_line, indent }` or
  `nil, reason` if no legal position can be determined.
- **`instalog/format.lua`** — pure string templating: given the format
  string (`%file`, `%line`, `%var`) and computed values, returns the
  finished log line text. No buffer/treesitter dependency.
- **`instalog/insert.lua`** — orchestrates: resolves the identifier under
  the cursor, calls `placement`, calls `format`, writes the line via
  `nvim_buf_set_lines`, and matches indentation.

`instalog.lua` (the public entrypoint) shrinks to `setup()` plus the
command handler. The existing stub command `InstalogNextLine` is renamed
to **`InstalogInsert`**, matching its actual behavior; its registration
moves with it (currently misregistered under `./instalog/instalog.lua`
rather than the conventional `./plugin/instalog.lua` — fixed as part of
this work since it affects whether the command is available at all).

## Placement algorithm

Each language's `print_definitions` entry carries two lists of
Tree-sitter node type names (discoverable via Neovim's built-in
`:InspectTree`):

- `block_types` — node types whose children form a statement sequence
  (e.g. `block`, `statement_block`, `chunk`, `class_body`, `program`).
- `container_types` — node types with a `body` field, where a signature
  or header may precede the body (e.g. `function_declaration`,
  `method_definition`, `for_statement`).

Given the cursor's Tree-sitter node, `placement.lua` walks up the
ancestor chain:

1. At each ancestor `A`, if `A`'s **parent**'s type is in `block_types`,
   then `A` is itself a statement inside that block: insert a new line
   immediately after `A`, matching `A`'s indentation. Stop.
2. Else if `A`'s type is in `container_types` and the cursor node is not
   already inside `A`'s `body` field subtree, then the target is `A`'s
   `body` field: insert as the first line inside that body, indented one
   level relative to `A`. Stop.
3. Otherwise continue to the next ancestor outward.
4. The top-level `program`/`chunk` node is always implicitly a member of
   `block_types`, so the walk is guaranteed to terminate: worst case, the
   log line is inserted after the top-level statement containing the
   cursor.

This single algorithm is generic across languages; only the two node-type
lists are per-language configuration.

## Data flow

1. `:InstalogInsert` fires → `insert.lua` reads `vim.bo.filetype`, looks
   up its `print_definitions` entry. Unconfigured filetype: warn and
   no-op (same UX as today's `context.lua`).
2. Get the Tree-sitter node at the cursor via `vim.treesitter.get_node()`.
   No parser/tree available for this buffer: warn and no-op.
3. Resolve the identifier text under the cursor from that node's text.
   Cursor not on an identifier node: notify and no-op.
4. `placement.lua` walks ancestors per the algorithm above, using the
   language's `block_types`/`container_types`, returning
   `{ insert_line, indent }`.
5. `format.lua` renders the template: `%file` (path relative to cwd,
   falling back to `~`-relative), `%line` (1-indexed insert line),
   `%var` (the identifier text).
6. `insert.lua` writes the line at `insert_line` with `indent` via
   `nvim_buf_set_lines`, leaves the cursor on the new line.

## Config schema

```lua
require('instalog').setup({
  format = '%file (Line %line): ',  -- global default
  print_definitions = {
    go = {
      log_statement = 'fmt.Println',
      block_types = { 'block' },
      container_types = { 'function_declaration', 'if_statement', 'for_statement' },
      format = '%file:%line ',       -- per-language override
    },
  },
})
```

Users add support for a new language, or extend an existing one, purely
through this config — no Lua code changes required.

## Error handling

- Unsupported filetype (no `print_definitions` entry): `vim.notify`
  warning, no-op.
- No Tree-sitter parser available for the buffer: `vim.notify` warning,
  no-op. Never fall back to inserting text blindly — that's exactly the
  syntax-breaking failure this plugin exists to prevent.
- Cursor not on an identifier node: `vim.notify` info ("place cursor on
  an identifier"), no-op.
- Walk exhausts the tree without a `block_types`/`container_types` match
  (a gap in that language's config): `vim.notify` warning naming the
  unmatched node type, so the user knows what to add to their config.

## Testing

Plenary specs per module, following the existing `context_spec.lua`
pattern:

- `format_spec.lua` — pure template substitution, no buffer needed.
- `placement_spec.lua` — table-driven: for each of the four default
  languages, a source snippet + cursor position + expected
  `{ insert_line, indent }`, covering both the "statement" case and the
  "header/signature → body" case from the spec's examples.
- `insert_spec.lua` (integration) — open a scratch buffer with real
  source, run `:InstalogInsert`, assert the resulting buffer lines.
