describe("format.render", function()
  local format = require("instalog.format")

  it("substitutes known placeholders", function()
    local result = format.render("%file (Line %line): ", { file = "test.ts", line = 3 })
    assert.equals("test.ts (Line 3): ", result)
  end)

  it("substitutes a var placeholder alongside file/line", function()
    local result = format.render("%file:%line %var", { file = "a.lua", line = 1, var = "x" })
    assert.equals("a.lua:1 x", result)
  end)

  it("leaves unrecognized placeholders literal instead of erroring", function()
    local result = format.render("%file %foo", { file = "a.go" })
    assert.equals("a.go %foo", result)
  end)
end)
