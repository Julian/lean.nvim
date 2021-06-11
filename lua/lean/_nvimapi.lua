local M = {}

-- Create autocmds under the specified group, clearing it first.
--
-- REPLACEME: once neovim/neovim#14661 is merged.
function M.set_augroup(name, autocmds)
  vim.api.nvim_exec(string.format([[
    augroup %s
      autocmd!
      %s
    augroup END
  ]], name, autocmds), false)
end

return M
