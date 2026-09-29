describe("config", function()
  local config = require("instalog.config")

  before_each(function()
    config.setup({})
  end)

  it("returns nil for an unconfigured filetype", function()
    assert.is_nil(config.get_language_config("missing"))
  end)

  it("returns the global format for a language with no override", function()
    local lang = config.get_language_config("lua")
    assert.equals("%file (Line %line): ", lang.format)
  end)

  it("lets a per-language format override the global default", function()
    config.setup({
      print_definitions = {
        go = { format = "%file:%line " },
      },
    })
    local go = config.get_language_config("go")
    assert.equals("%file:%line ", go.format)
    -- other languages are unaffected and still see the global default
    local lua_lang = config.get_language_config("lua")
    assert.equals("%file (Line %line): ", lua_lang.format)
  end)

  it("deep-merges user print_definitions over defaults instead of replacing them", function()
    config.setup({
      print_definitions = {
        go = { log_statement = "log.Println" },
      },
    })
    local go = config.get_language_config("go")
    assert.equals("log.Println", go.log_statement)
    -- block_types/container_types survive the merge since we only overrode log_statement
    assert.is_true(#go.block_types > 0)
  end)
end)
