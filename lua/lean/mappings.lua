local M = {}

function M.use_suggested_mappings()
local opts = {noremap = true, silent = true}
vim.api.nvim_buf_set_keymap(
  0, 'n', '<LocalLeader>i', "<Cmd>lua require('lean.infoview').toggle()<CR>", opts
)
vim.api.nvim_buf_set_keymap(
  0, 'n', '<LocalLeader>pt', "<Cmd>lua require('lean.infoview').set_pertab()<CR>", opts
)
vim.api.nvim_buf_set_keymap(
  0, 'n', '<LocalLeader>pw', "<Cmd>lua require('lean.infoview').set_perwindow()<CR>", opts
)
vim.api.nvim_buf_set_keymap(
  0, 'n', '<LocalLeader>s', "<Cmd>lua require('lean.sorry').fill()<CR>", opts
)
vim.api.nvim_buf_set_keymap(
  0, 'n', '<LocalLeader>t', "<Cmd>lua require('lean.trythis').swap()<CR>", opts
)
end

return M
