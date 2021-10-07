local M = {}
M.detect = function(filename)
  vim.opt.filetype = require('lean.lean3').__detect_regex(filename) and 'lean3' or 'lean'
end
return M
