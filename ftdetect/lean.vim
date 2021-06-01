autocmd BufRead,BufNewFile *.lean lua require'lean.ft'.detect(); require'lean.lean3'.detect()
