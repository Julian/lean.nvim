local M = {}

local lean3 = require("lean.lean3")

function M.detect()
  vim.api.nvim_command("setfiletype lean")
  if lean3.is_lean3_project() then lean3.init() end
end

return M
