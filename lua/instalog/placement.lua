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
