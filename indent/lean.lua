if vim.b.did_indent then
  return
end
---@diagnostic disable-next-line: inject-field
vim.b.did_indent = true

vim.bo.lisp = false
vim.bo.indentexpr = [[v:lua.require('lean.indent').indentexpr()]]
vim.bo.indentkeys = vim.bo.indentkeys:gsub('0#', '')
vim.bo.smartindent = false

vim.b.undo_indent = table.concat({
  'setlocal indentexpr<',
  'lisp<',
  'smartindent<',
}, ' ')
