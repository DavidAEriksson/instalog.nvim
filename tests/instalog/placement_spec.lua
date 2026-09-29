local placement = require("instalog.placement")
local config = require("instalog.config")

local function set_buffer_lines(lines, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", filetype)
  vim.bo[buf].expandtab = true
  vim.bo[buf].shiftwidth = 2
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

  it("inserts as the first line of an empty multi-line function body when cursor is in the signature (typescript)", function()
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

  it("inserts before the body's first statement, using its own indentation, when cursor is in the signature (typescript)", function()
    local buf = set_buffer_lines({
      "function myFunc(param) {",
      "  return param",
      "}",
    }, "typescript")
    -- cursor on "param" (row 0, col 17)
    local node = vim.treesitter.get_node({ bufnr = buf, pos = { 0, 17 } })
    local lang = config.get_language_config("typescript")
    local row, indent = placement.find_insertion_point(node, lang)
    assert.equals(1, row)
    assert.equals("  ", indent)
  end)

  it("gives up rather than insert outside a single-line function body (typescript)", function()
    local buf = set_buffer_lines({ "function myFunc(param) { return param }" }, "typescript")
    -- cursor on "param" (row 0, col 17)
    local node = vim.treesitter.get_node({ bufnr = buf, pos = { 0, 17 } })
    local lang = config.get_language_config("typescript")
    local row, reason = placement.find_insertion_point(node, lang)
    assert.is_nil(row)
    assert.is_string(reason)
  end)

  it("resolves via the top-level fallback when nothing else matches (lua)", function()
    local buf = set_buffer_lines({ 'local value = "hello"' }, "lua")
    local node = vim.treesitter.get_node({ bufnr = buf, pos = { 0, 6 } })
    local lang = config.get_language_config("lua")
    local row, indent = placement.find_insertion_point(node, lang)
    assert.equals(1, row)
    assert.equals("", indent)
  end)

  it("inserts before the body's first statement when cursor is in the signature (lua)", function()
    local buf = set_buffer_lines({
      "local function myFunc(param)",
      "  return param",
      "end",
    }, "lua")
    -- cursor on "param" (row 0, col 23)
    local node = vim.treesitter.get_node({ bufnr = buf, pos = { 0, 23 } })
    local lang = config.get_language_config("lua")
    local row, indent = placement.find_insertion_point(node, lang)
    assert.equals(1, row)
    assert.equals("  ", indent)
  end)

  it("inserts before the body's first statement when cursor is in the signature (python)", function()
    local buf = set_buffer_lines({
      "def f(x):",
      "    return x",
    }, "python")
    -- cursor on "x" (row 0, col 6)
    local node = vim.treesitter.get_node({ bufnr = buf, pos = { 0, 6 } })
    local lang = config.get_language_config("python")
    local row, indent = placement.find_insertion_point(node, lang)
    assert.equals(1, row)
    assert.equals("    ", indent)
  end)

  it("inserts before the body's first statement when cursor is in the signature (go)", function()
    local buf = set_buffer_lines({
      "func f(p int) {",
      "\treturn",
      "}",
    }, "go")
    -- cursor on "p" (row 0, col 7)
    local node = vim.treesitter.get_node({ bufnr = buf, pos = { 0, 7 } })
    local lang = config.get_language_config("go")
    local row, indent = placement.find_insertion_point(node, lang)
    assert.equals(1, row)
    assert.equals("\t", indent)
  end)

  it("gives up rather than insert outside a single-line empty function body (go)", function()
    local buf = set_buffer_lines({ "func f(p int) {}" }, "go")
    -- cursor on "p" (row 0, col 7)
    local node = vim.treesitter.get_node({ bufnr = buf, pos = { 0, 7 } })
    local lang = config.get_language_config("go")
    local row, reason = placement.find_insertion_point(node, lang)
    assert.is_nil(row)
    assert.is_string(reason)
  end)
end)
