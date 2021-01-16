set display=lastline  " Avoid neovim/neovim#11362
set noswapfile

set rtp+=.
set rtp+=../completion-nvim/
set rtp+=../nvim-lspconfig/
set rtp+=../plenary.nvim/
set rtp+=../snippets.nvim/

runtime! plugin/plenary.vim

lua <<EOF
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
EOF
