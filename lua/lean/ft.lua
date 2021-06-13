local M = {}

local lean3 = require("lean.lean3")

function M.detect()
  if lean3.is_lean3_project() then lean3.init() end
  vim.bo.ft = "lean"
end

return M
