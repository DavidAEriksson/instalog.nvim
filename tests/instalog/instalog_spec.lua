local instalog = require("instalog")

describe("setup", function()
  it("works with default", function()
    assert("my first function with param = Hello!", instalog.hello())
  end)

  it("works with custom var", function()
    instalog.setup({ opt = "custom" })
    assert("my first function with param = custom", instalog.hello())
  end)
end)
