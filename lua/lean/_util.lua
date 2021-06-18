-- Stuff that should live in some standard library.

local M = {}

--- Return an array-like table with a value repeated the given number of times.
function M.tbl_repeat(value, times)
  local result = {}
  for _ = 1, times do table.insert(result, value) end
  return result
end

return M
