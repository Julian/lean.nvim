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
    })
    :join ','
end

local config = require 'lean.config'()

vim.bo.modifiable = config.ft:should_modify()

if config.mappings == true then
  require('lean').use_suggested_mappings(0)

  local edit = require('lean.edit')

  vim.keymap.set('n', '[m', edit.declaration.goto_start, {
    buffer = true,
    desc = 'Move to the previous declaration start.',
  })
  vim.keymap.set('n', ']m', edit.declaration.goto_end, {
    buffer = true,
    desc = 'Move to the next declaration end.',
  })
end
