local Buffer = require 'std.nvim.buffer'
local Window = require 'std.nvim.window'

-- In case recording crashes.
vim.o.directory = ''
vim.o.shada = ''

DEMO = {}

---Show an overlay ready for a popup message.
---
---Leaves actually typing and then exiting to be driven within VHS.
function DEMO.popup()
  local width = 70
  local height = 10
  local buffer = Buffer.create{ listed = false, scratch = true }
  local win = Window:from_id(vim.api.nvim_open_win(buffer.bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    zindex = 50,
    style = 'minimal',
    border = 'rounded',
  }))
  win.o.wrap = true
  win.o.winblend = 10
  win.o.winhighlight = 'Normal:Normal,FloatBorder:FloatBorder'
  buffer.o.filetype = 'markdown'
  buffer.b.completion = false -- disable blink, completion popping up is noisy
  vim.cmd.startinsert()
end
