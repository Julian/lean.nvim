local M = {}
if vim.fn.executable("elan") == 1 then
  M.detect = vim.schedule_wrap(function(filename)
    vim.opt.filetype = require('lean.lean3').__detect_elan(filename) and 'lean3' or 'lean'
  end)
else
  M.detect = function(filename)
    vim.opt.filetype = require('lean.lean3').__detect_regex(filename) and 'lean3' or 'lean'
  end
end
return M
