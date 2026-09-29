local placement = require("instalog.placement")
local config = require("instalog.config")

local function set_buffer_lines(lines, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", filetype)
  vim.api.nvim_set_current_buf(buf)
  vim.treesitter.start(buf, filetype)
  vim.treesitter.get_parser(buf, filetype):parse()
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
