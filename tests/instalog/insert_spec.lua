local insert = require("instalog.insert")
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

    local cursor = vim.api.nvim_win_get_cursor(0)
    assert.equals(2, cursor[1])
  end)

  it("inserts a console.log line for a destructured parameter's shorthand binding (typescript)", function()
    local buf = set_buffer_lines({
      "function BoxImagePreview({ image }: { image: BoxImage }) {",
      "}",
    }, "typescript")
    vim.api.nvim_win_set_cursor(0, { 1, 27 }) -- on "image" inside the destructuring pattern

    insert.insert_log()

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.matches('^  console%.log%(".*%(Line 2%): ", image%)$', lines[2])
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

  it("notifies and does not insert when the filetype is configured but has no installed parser", function()
    config.setup({
      print_definitions = {
        cobol = {
          log_statement = "DISPLAY",
          block_types = { "program" },
          container_types = {},
        },
      },
    })
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "some cobol source" })
    vim.api.nvim_buf_set_option(buf, "filetype", "cobol")
    vim.api.nvim_set_current_buf(buf)
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
