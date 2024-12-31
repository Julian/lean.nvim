if vim.b.did_ftplugin then
  return
end
vim.b.did_ftplugin = 1

vim.opt.wildignore:append [[*.olean]]

vim.bo.iskeyword = [[a-z,A-Z,_,48-57,192-255,!,',?]]
vim.bo.comments = [[s0:/-,mb:\ ,ex:-/,:--]]
vim.bo.commentstring = [[/- %s -/]]

vim.bo.includeexpr = [[substitute(v:fname, '\.', '/', 'g') . '.lean']]

vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.softtabstop = 2

vim.opt_local.matchpairs:append [[⟨:⟩]]
vim.opt_local.matchpairs:append [[‹:›]]
vim.opt_local.matchpairs:append [[«:»]]

-- Matchit support
if vim.g.loaded_matchit and not vim.b.match_words then
  vim.b.match_ignorecase = 0
  vim.b.match_words = vim
    .iter({
      [[\<\%(namespace\|section\)\s\+\([^«»]\{-}\>\|«.\{-}»\):\<end\s\+\1]],
      [[^\s*section\s*$:^end\s*$]],
      [[\<if\>:\<then\>:\<else\>]],
      [[\<do\>:\<return\>]],
    })
    :join ','
end

local config = require 'lean.config'()

if config.mappings == true then
  require('lean').use_suggested_mappings(0)
end

vim.bo.modifiable = config.ft:should_modify()
