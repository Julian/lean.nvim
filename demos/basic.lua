local Popup = require 'nui.popup'

-- In case recording crashes.
vim.opt.directory = ''
vim.opt.shada = ''

DEMO = {
  overlay_opts = {
    position = '50%',
    size = { width = 70, height = 10 },
    enter = true,
    focusable = true,
    zindex = 50,
    relative = 'editor',
    border = {
      padding = { top = 2, bottom = 2, left = 3, right = 3 },
      style = 'rounded',
    },
    buf_options = { modifiable = true, readonly = false },
    win_options = {
      wrap = true,
      winblend = 10,
      winhighlight = 'Normal:Normal,FloatBorder:FloatBorder',
    },
  },
}

---Show an overlay ready for a popup message.
---
---Leaves actually typing and then exiting to be driven within VHS.
function DEMO.popup()
  Popup(DEMO.overlay_opts):mount()
  vim.cmd.startinsert()
end
