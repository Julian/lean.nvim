local subprocess_check_output = require('lean._util').subprocess_check_output
local elan = {}

---Dump elan's state.
---@return table
function elan.state()
  local stdout = subprocess_check_output { 'elan', 'dump-state' }
  return vim.json.decode(stdout)
end

return elan
