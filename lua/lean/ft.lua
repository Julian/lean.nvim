return {
  detect = function()
    vim.opt.filetype = require('lean.lean3').__detect() and 'lean3' or 'lean'
  end
}
