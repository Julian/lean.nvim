if vim.b.did_ftplugin then return end
vim.b.did_ftplugin = 1

vim.opt.wildignore:append[[*.olean]]

vim.opt_local.iskeyword = [[@,48-57,_,-,.,!,#,$,%]]
vim.opt_local.comments = [[s0:/-,mb:\ ,ex:-/,:--]]
vim.opt_local.commentstring=[[/- %s -/]]

vim.opt_local.includeexpr = [[substitute(v:fname, '\.', '/', 'g') . '.lean']]

vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 2
vim.opt_local.softtabstop = 2

vim.opt_local.matchpairs:append[[⟨:⟩]]

-- Matchit support
if vim.g.loaded_matchit and not vim.b.match_words then
  vim.b.match_ignorecase = 0
  vim.b.match_words = table.concat(
    {
        [[\<begin\>:\<end\ze\%(\,\|$\)]],
        [[\<\%(namespace\|section\)\s\+\(.\{-}\)\>:\<end\s\+\1\>]],
    },
    ','
  )
end

require'lean.ft'.__maybe_make_nomodifiable(vim.api.nvim_get_current_buf())
