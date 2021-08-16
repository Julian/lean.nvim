local M = {}
if vim.fn.executable"elan" then
  M.detect =
  vim.schedule_wrap(function()
    vim.opt.filetype = require('lean.lean3').__detect_elan() and 'lean3' or 'lean'
  end)
else
  M.detect = function()
    vim.opt.filetype = require('lean.lean3').__detect_regex() and 'lean3' or 'lean'
  end
end
return M
