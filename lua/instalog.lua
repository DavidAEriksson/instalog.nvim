local config = require('instalog.config')

local M = {}

M.setup = function(user_config)
  config.setup(user_config)
end

return M
