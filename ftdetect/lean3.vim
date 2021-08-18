autocmd BufRead,BufNewFile *.lean lua require'lean.ft'.detect(vim.fn.expand('<afile>'))
