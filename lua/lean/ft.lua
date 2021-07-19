local ft = {}

local lean3 = require('lean.lean3')

function ft.detect()
  ft.set(lean3.detect() and 'lean3' or 'lean')
end

function ft.set(filetype)
  vim.api.nvim_command("setfiletype " .. filetype)
  if vim.bo.ft == "lean3" then lean3.init() end
end

return ft
