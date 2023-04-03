local instalog = require("instalog")

describe("setup", function()
  it("works with default", function()
    assert("my first function with param = Hello!", instalog.next_line())
  end)

  it("works with custom var", function()
    instalog.setup({ opt = "custom" })
    assert("my first function with param = custom", instalog.next_line())
  end)
end)
