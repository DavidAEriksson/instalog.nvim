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

-- The unit used for a newly-invented indent level (the empty-body
-- fallback below). Indentation borrowed directly from existing source
-- text never goes through this - only used when there is no sibling
-- line to copy indentation from.
local function indent_unit(bufnr)
  if not vim.bo[bufnr].expandtab then
    return '\t'
  end
  local width = vim.bo[bufnr].shiftwidth
  if width == 0 then
    width = vim.bo[bufnr].tabstop
  end
  return string.rep(' ', width)
end

-- Body node's own start row is only a `{`-style delimiter line in
-- brace-based grammars (typescript/javascript/go/lua's `function...end`).
-- In indentation-based grammars (python, and lua's `block` node for
-- `if`/`for`/`while` bodies) the body node starts on the SAME row as its
-- first statement - there is no separate delimiter line to skip past.
-- Deriving the insertion point from the body's first named child (when
-- one exists) instead of blindly adding 1 to the body's own start row
-- handles both shapes, and borrows real indentation from an existing
-- sibling rather than inventing one.
local function insertion_point_in_body(bufnr, container, body)
  local body_start_row, _, body_end_row = body:range()
  local container_start_row = container:range()
  local first_child = body:named_child(0)

  if first_child then
    local first_row = first_child:range()
    if first_row > container_start_row then
      return first_row, indent_of(bufnr, first_row)
    end
    -- First statement shares the container's own line (a single-line
    -- body with content): no line exists to insert without landing
    -- outside the container's scope.
    return nil, string.format('cannot insert into single-line body of "%s"', container:type())
  end

  if body_end_row > body_start_row then
    -- Empty body spanning multiple lines, e.g. `function f() {\n}`.
    return body_start_row + 1, indent_of(bufnr, container_start_row) .. indent_unit(bufnr)
  end

  -- Empty body on a single line, e.g. `func f() {}`.
  return nil, string.format('cannot insert into single-line body of "%s"', container:type())
end

M.find_insertion_point = function(node, lang_config)
  local bufnr = vim.api.nvim_get_current_buf()
  local current = node
  local last_type = current and current:type() or nil

  while current do
    last_type = current:type()

    -- Check container_types BEFORE checking the parent-is-a-block rule.
    -- Walking outward from the cursor, if the cursor were already inside
    -- this container's body, an inner ancestor whose parent is a
    -- block_types node would have matched and returned already. So
    -- reaching a container node here always means the cursor is still in
    -- its header/signature, and redirecting into its body is correct.
    if contains(lang_config.container_types, current:type()) then
      local body = resolve_body_field(current)
      if body then
        return insertion_point_in_body(bufnr, current, body)
      end
    end

    local parent = current:parent()
    if parent and contains(lang_config.block_types, parent:type()) then
      local start_row, _, end_row = current:range()
      return end_row + 1, indent_of(bufnr, start_row)
    end

    current = parent
  end

  return nil,
    string.format('no matching block_types or container_types ancestor found (stopped at "%s")', last_type or 'unknown')
end

return M
