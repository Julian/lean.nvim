vim.bo.modifiable = false
vim.bo.undolevels = -1
vim.wo.cursorline = false
vim.wo.cursorcolumn = false
vim.wo.colorcolumn = ""
vim.wo.number = false
vim.wo.relativenumber = false
vim.wo.spell = false
vim.wo.winfixheight = true
vim.wo.winfixwidth = true
vim.wo.wrap = true
if vim.fn.exists('&winfixbuf') > 0 then
  vim.wo.winfixbuf = true
end
