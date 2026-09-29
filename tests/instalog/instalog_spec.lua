describe("instalog.setup", function()
  local instalog = require("instalog")
  local config = require("instalog.config")

  it("delegates to config.setup", function()
    instalog.setup({ format = "%file %line" })
    assert.equals("%file %line", config.options.format)
  end)
end)
