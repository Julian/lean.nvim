local Buffer = require 'std.nvim.buffer'
local Window = require 'std.nvim.window'

-- In case recording crashes.
vim.o.directory = ''
vim.o.shada = ''

DEMO = {}

---Show a persistent key press display in the bottom-right corner.
function DEMO.show_keys()
  local width = 40
  local buffer = Buffer.create { listed = false, scratch = true }
  buffer.o.modifiable = true
  local win = Window:from_id(vim.api.nvim_open_win(buffer.bufnr, false, {
    relative = 'editor',
    width = width,
    height = 1,
    col = vim.o.columns - width - 2,
    row = vim.o.lines - 4,
    zindex = 100,
    style = 'minimal',
    border = 'rounded',
    focusable = false,
  }))
  win.o.winhighlight = 'Normal:Normal,FloatBorder:FloatBorder'

  local keys = {}
  local timer = vim.uv.new_timer()

  vim.on_key(function(_, typed)
    if typed == '' then
      return
    end
    local display = vim.fn.keytrans(typed)
    if display == '' then
      return
    end
    table.insert(keys, display)
    -- Keep only the most recent keystrokes that fit.
    while #table.concat(keys, ' ') > width - 2 do
      table.remove(keys, 1)
    end
    vim.schedule(function()
      if not buffer:is_valid() then
        return
      end
      buffer:set_lines { ' ' .. table.concat(keys, ' ') }
    end)
    timer:stop()
    timer:start(
      1500,
      0,
      vim.schedule_wrap(function()
        keys = {}
        if not buffer:is_valid() then
          return
        end
        buffer:set_lines { '' }
      end)
    )
  end)
end

---Show a centered overlay popup.
---
---If lines are given, they are displayed read-only.
---Otherwise the popup is empty and enters insert mode for VHS to type into.
---@param lines? string[]
function DEMO.popup(lines)
  local width = 70
  local height = lines and math.max(#lines + 2, 5) or 10
  local buffer = Buffer.create { listed = false, scratch = true }
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
  if lines then
    buffer:set_lines(lines)
    buffer.o.modifiable = false
  else
    vim.cmd.startinsert()
  end
end

---Wait for the infoview to have content after opening a Lean file.
---Call after navigating to the target cursor position.
---@param opts? { timeout?: number }
function DEMO.wait_for_infoview(opts)
  opts = opts or {}
  local timeout = opts.timeout or 30000
  local infoview = require 'lean.infoview'
  vim.wait(timeout, function()
    local iv = infoview.get_current_infoview()
    if not iv then
      return false
    end
    local lines = iv:get_lines()
    return #lines > 0 and lines[1] ~= ''
  end, 200)
end

---Dismiss all floating windows then show a summary end card.
---@param lines string[]
function DEMO.end_card(lines)
  for _, id in ipairs(vim.api.nvim_list_wins()) do
    local win = Window:from_id(id)
    if win:config().relative ~= '' then
      win:force_close()
    end
  end
  DEMO.popup(lines)
end
