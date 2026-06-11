if vim.b.did_ftplugin then
  return
end
vim.b.did_ftplugin = 1

vim.opt.wildignore:append [[*.olean]]

vim.bo.iskeyword = [[a-z,A-Z,_,48-57,192-255,!,',?,#]]
vim.bo.comments = [[s0:/-,mb: ,ex:-/,:--]]
vim.bo.commentstring = [[-- %s]]

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
      [[\/\-[-\s]\?:-\/]],
    })
    :join ','
end

local lean = require 'lean'

-- Normally our plugin/ files already ran this, making it a no-op beyond
-- retrying integration with optional plugins (e.g. telescope.nvim) which may
-- have loaded after they did -- but it also serves as a safety net for
-- plugin managers configured to skip sourcing them.
lean.init()

local config = require 'lean.config'()

if config.mappings == true then
  lean.use_suggested_mappings(0)
end

if config.inlay_hint.enabled then
  vim.lsp.inlay_hint.enable(true, { bufnr = 0 })
end

-- Start the Kitty graphics protocol probe eagerly so it resolves before any
-- SVG content arrives from the Lean server.
if config.graphics.enabled then
  require 'kitty'
end

local bufnr = vim.api.nvim_get_current_buf()
require('lean.abbreviations').init(bufnr)
require('lean.infoview').init(bufnr)
require('lean.progress_bars').init(bufnr)
require('lean.stderr').init()

vim.bo.modifiable = config.ft:should_modify()

vim.api.nvim_create_autocmd('DiagnosticChanged', {
  group = vim.api.nvim_create_augroup('LeanDiagnostics', { clear = false }),
  buffer = 0,
  callback = function(args)
    -- If the buffer is no longer loaded, bail.
    -- We could instead choose to un-register the autocmd if we notice this has
    -- happened, but then we'd need to put it back again if it's loaded again.
    if not vim.api.nvim_buf_is_loaded(args.buf) then
      return
    end

    local uri = vim.uri_from_bufnr(args.buf)
    vim.schedule(function()
      require('lean.infoview').__update_pin_by_uri(uri)
    end)
  end,
})
