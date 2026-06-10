---@brief [[
--- Tests for kitty graphics overlay placement.
---
--- Stubs out terminal detection and captures emitted escape sequences, so
--- these run regardless of what terminal the suite runs in.
---@brief ]]

local Buffer = require 'std.nvim.buffer'
local Window = require 'std.nvim.window'

local Element = require('lean.tui').Element
local kitty = require 'kitty'

require 'spec.helpers'

---A fake 16x16 image overlay.
local OVERLAY = { data = ('\0'):rep(16 * 16 * 4), width = 16, height = 16, format = 32 }

---Render the element in a new vertical split, capturing kitty escapes.
---@param element Element
---@param configure? fun(win: integer) tweak the window before rendering
---@return string? place the captured placement escape
---@return integer[] winpos the window's position
local function render_capturing(element, configure)
  local available = kitty.available
  kitty.available = function()
    return true
  end
  local sent = {}
  local chan_send = vim.api.nvim_chan_send
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.api.nvim_chan_send = function(_, data)
    table.insert(sent, data)
  end

  vim.cmd 'botright 40vsplit'
  local win = vim.api.nvim_get_current_win()
  if configure then
    configure(win)
  end
  local buffer = Buffer.create { scratch = true }
  vim.api.nvim_win_set_buf(win, buffer.bufnr)

  local renderer = element:renderer { buffer = buffer }
  renderer.last_window = Window:from_id(win)
  renderer:render()

  local winpos = vim.api.nvim_win_get_position(win)

  -- Close before restoring the stubs so cleanup escapes are captured too.
  renderer:close()
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  vim.api.nvim_chan_send = chan_send
  kitty.available = available

  local place = vim.iter(sent):find(function(data)
    return data:find('a=p', 1, true)
  end)
  return place, winpos
end

describe('overlay placement', function()
  it('places inline overlays at their display column', function()
    local place, winpos = render_capturing(
      Element:new {
        children = {
          -- a multibyte (but 12 display cell) prefix
          Element:new { text = '⊢ Try this: ' },
          Element:new { text = '  ', overlay = OVERLAY },
        },
      },
      function(win)
        vim.wo[win].signcolumn = 'yes:2' -- shift text right 4 cells
      end
    )

    assert.message('no placement was emitted').is_not_nil(place)
    local row, col = place:match '\27%[(%d+);(%d+)H'
    assert.is.equal(winpos[2] + 4 + 12 + 1, tonumber(col))
    assert.is.equal(winpos[1] + 1, tonumber(row))
  end)

  it('places overlays below soft-wrapped lines at their screen row', function()
    local place, winpos = render_capturing(Element:new {
      children = {
        -- wraps onto 2 screen rows in our 40 cell wide window
        Element:new { text = ('x'):rep(60) .. '\n' },
        Element:new { text = '  ', overlay = OVERLAY },
      },
    })

    assert.message('no placement was emitted').is_not_nil(place)
    local row, col = place:match '\27%[(%d+);(%d+)H'
    assert.is.equal(winpos[2] + 1, tonumber(col))
    assert.is.equal(winpos[1] + 2 + 1, tonumber(row))
  end)
end)
