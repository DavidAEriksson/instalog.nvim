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
