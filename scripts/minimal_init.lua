vim.o.display = 'lastline'  -- Avoid neovim/neovim#11362
vim.bo.swapfile = false

local __file__ = debug.getinfo(1).source:match("@(.*)$")
local lean_nvim_dir = vim.fn.fnamemodify(__file__, ':p:h:h')
local packpath = lean_nvim_dir .. '/packpath/*'
vim.o.runtimepath = vim.o.runtimepath .. ',' .. packpath .. ',' .. lean_nvim_dir

vim.api.nvim_exec([[
  autocmd BufNewFile,BufRead *.lean setlocal filetype=lean

  runtime! plugin/completion.vim
  runtime! plugin/lspconfig.vim
  runtime! plugin/plenary.vim
]], false)

require('lean').setup{}

function tab()
  local _, expanded = require('snippets').lookup_snippet_at_cursor()
  if expanded ~= nil then
    require('snippets').expand_at_cursor()
    return
  end
  require('completion').smart_tab()
end

vim.api.nvim_set_keymap('i', '<Tab>', '<Cmd>lua tab()<CR>', {})
