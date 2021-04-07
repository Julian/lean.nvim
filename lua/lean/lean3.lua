local M = {}

function M.init()
  pcall(vim.cmd, 'TSBufDisable highlight')
  vim.b.lean3 = true
end

return M
