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
