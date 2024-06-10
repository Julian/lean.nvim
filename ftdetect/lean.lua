vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*.lean',
  callback = function(_)
    vim.bo.filetype = 'lean'
  end,
})
