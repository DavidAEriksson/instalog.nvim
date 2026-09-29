local M = {}

M.render = function(template, values)
  local result = template:gsub('%%(%a+)', function(key)
    if values[key] ~= nil then
      return tostring(values[key])
    end
    return '%' .. key
  end)
  return result
end

return M
