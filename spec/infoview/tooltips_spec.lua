---@brief [[
--- Tests for tooltips (rendered inside infoviews).
---
--- Really this should combine with the user widget tests (which it preceeds).
---@brief ]]

local Tab = require 'std.nvim.tab'
local Window = require 'std.nvim.window'

local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe(
  'infoview widgets',
  helpers.clean_buffer('#check Nat', function()
    local lean_window = Window:current()
    local current_infoview = infoview.get_current_infoview()

    it('shows widget tooltips', function()
      helpers.move_cursor { to = { 1, 8 } }
      assert.infoview_contents.are [[
        ▼ expected type (1:8-1:11)
        ⊢ Type

        ▼ 1:1-1:7: information:
        Nat : Type
      ]]

      current_infoview:enter()
      helpers.move_cursor { to = { 2, 5 } } -- `Type`

      local known_windows = { lean_window, Window:from_id(current_infoview.window) }
      assert.windows.are(lean_window.id, current_infoview.window)

      helpers.feed '<CR>'
      local tooltip_bufnr = helpers.wait_for_new_window(known_windows):bufnr()
      assert.contents.are {
        'Type : Type 1\n\nA type universe. `Type ≡ Type 0`, `Type u ≡ Sort (u + 1)`. ',
        bufnr = tooltip_bufnr,
      }

      -- Close the tooltip.
      helpers.feed '<Esc>'
      assert.windows.are(lean_window.id, current_infoview.window)
    end)

    it('does not abandon tooltips when the infoview is closed', function()
      vim.cmd.tabnew '#'
      local tab2_window = Window:current()
      local tab2_infoview = infoview.get_current_infoview()
      helpers.move_cursor { to = { 1, 9 } }
      helpers.wait_for_loading_pins()
      tab2_infoview:enter()
      helpers.move_cursor { to = { 2, 5 } } -- `Type`
      helpers.feed '<CR>'

      helpers.wait_for_new_window { tab2_window, Window:from_id(tab2_infoview.window) }
      assert.is.equal(3, #Tab:current():windows())

      -- Now close the infoview entirely, and the tooltip should close too.
      tab2_infoview:close()

      assert.is.equal(1, #Tab:current():windows())
      tab2_window:close()

      assert.is.equal(1, #Tab:all())
    end)

    it('does not abandon tooltips when windows are closed', function()
      vim.cmd.tabnew '#'
      local tab2_window = Window:current()
      local tab2_infoview = infoview.get_current_infoview()
      helpers.move_cursor { to = { 1, 8 } }
      helpers.wait_for_loading_pins()
      tab2_infoview:enter()
      helpers.move_cursor { to = { 2, 5 } } -- `Type`
      helpers.feed '<CR>'

      helpers.wait_for_new_window { tab2_window, Window:from_id(tab2_infoview.window) }
      assert.is.equal(3, #Tab:current():windows())

      assert.is.equal(2, #Tab:all())

      -- Now close the other 2 windows, and the tooltip should close too.
      vim.api.nvim_win_close(tab2_infoview.window, false)
      tab2_window:close()

      assert.is.equal(1, #Tab:all())
    end)
  end)
)

describe(
  'contents',
  helpers.clean_buffer('#check Nat', function()
    it(
      'shows diagnostics',
      helpers.clean_buffer('example : 37 = 37 := by', function()
        helpers.move_cursor { to = { 1, 19 } }
        assert.infoview_contents.are [[
          ▼ 1:22-1:24: error:
          unsolved goals
          ⊢ 37 = 37
        ]]
      end)
    )
  end)
)
