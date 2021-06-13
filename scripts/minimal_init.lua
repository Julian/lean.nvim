vim.o.display = 'lastline'  -- Avoid neovim/neovim#11362
vim.o.directory = ''

local __file__ = debug.getinfo(1).source:match("@(.*)$")
local lean_nvim_dir = vim.fn.fnamemodify(__file__, ':p:h:h')
local packpath = lean_nvim_dir .. '/packpath/*'
vim.o.runtimepath = vim.o.runtimepath .. ',' .. packpath .. ',' .. lean_nvim_dir

vim.api.nvim_exec([[
  autocmd BufNewFile,BufRead *.lean setlocal filetype=lean3

  runtime! plugin/lspconfig.vim
  runtime! plugin/plenary.vim
]], false)
