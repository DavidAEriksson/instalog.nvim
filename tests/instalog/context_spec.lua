local mock = require('luassert.mock')

describe("context", function()
  local context = require("instalog.context")
  it("returns table for existing filetype", function()
    vim.opt_local.filetype = "lua"
    local lang_def = context.get_file_defs()
    assert(type(lang_def) == 'table')
  end)

  it("returns nil for missing filetype", function()
    local api = mock(vim.api, true)
    vim.opt_local.filetype = "missing"
    api.notify.returns('ok')
    local lang_def = context.get_file_defs()
    assert(type(lang_def) == 'nil')
  end)
end)
