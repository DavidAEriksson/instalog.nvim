local config = require('instalog.config')
local insert = require('instalog.insert')

local M = {}

M.setup = function(user_config)
  config.setup(user_config)
end

M.insert_log = function()
  insert.insert_log()
end

return M
