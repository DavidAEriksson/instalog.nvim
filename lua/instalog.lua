-- main module file
local module = require("instalog.context")

local M = {}

M.config = {
  -- default config
  opt = "Hello!",
}

-- setup is the public method to setup your plugin
M.setup = function(args)
  -- you can define your setup function here. Usually configurations can be merged, accepting outside params and
  -- you can also put some validation here for those.
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

M.next_line = function()
  local curr_line = module.get_file_defs()
  vim.print(curr_line)
end

return M
