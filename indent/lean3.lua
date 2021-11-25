if vim.b.did_indent then return end
vim.b.did_indent = 1
vim.opt_local.indentkeys:append { "=begin", "=end" }
