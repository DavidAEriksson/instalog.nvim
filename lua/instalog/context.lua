local print_definitions = require('instalog.print_definitions')
-- local ts_utils = require("nvim-treesitter.ts_utils")

local M = {}

M.get_file_defs = function()
  local filetype = vim.bo.filetype
  local lang_defs = print_definitions[filetype]
  if not lang_defs then
    vim.notify("Filetype " .. filetype .. " is not supported. \nPlease refer to instalog/print_definitions.lua.", 4)
    return
  end

  return lang_defs
end

return M
