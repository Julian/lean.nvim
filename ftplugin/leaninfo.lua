vim.bo.modifiable = false
vim.bo.undolevels = -1
vim.wo.cursorline = false
vim.wo.cursorcolumn = false
vim.wo.colorcolumn = ''
vim.wo.number = false
vim.wo.relativenumber = false
vim.wo.spell = false
vim.wo.winfixheight = true
vim.wo.winfixwidth = true
vim.wo.wrap = true
if vim.fn.exists '&winfixbuf' ~= 0 then
  local wo = vim.wo[vim.api.nvim_get_current_win()]
  -- FIXME: This is obviously ridiculous, but there's seemingly some neovim bug
  --        here which needs minimizing.
  --        The symptoms are that when opening a stacked (vertical) infoview
  --        -- and only when opening a vertical one -- we were opening *2*
  --        identically named windows (lean://.../curr)
  --        The line which triggers this behavior is the line which sets
  --        filetype = leaninfo, i.e. which triggers this file to run, and
  --        specifically the line which triggers it is this one.
  --        So something is going wrong where winfixbuf cannot run that early
  --        on in a window being set up, even though we do not change the
  --        infoview buffer anytime after that filetype line.
  --        Somehow vim.schedule delays things long enough that they work
  --        correctly, including winfixbuf getting set.
  --        We'll minimize. Some day.
  vim.schedule(function()
    wo.winfixbuf = true
  end)
end
