---@brief [[
---Tests for Lean widgets (rendered inside infoviews).
---@brief ]]

local infoview = require('lean.infoview')
local helpers = require('tests.helpers')

require('lean').setup{}

describe('infoview widgets', function()
  describe('lean 4', helpers.clean_buffer('lean', '#check Nat', function()

    local lean_window = vim.api.nvim_get_current_win()
    local current_infoview = infoview.get_current_infoview()

    it('shows widget tooltips', function(_)
      helpers.move_cursor{ to = {1, 8} }
      assert.infoview_contents.are[[
        ▶ expected type (1:8-1:11)
        ⊢ Type

        ▶ 1:1-1:7: information:
        Nat : Type
      ]]

      vim.api.nvim_set_current_win(current_infoview.window)
      helpers.move_cursor{ to = {2, 4} }  -- `Type`

      local known_windows = { lean_window, current_infoview.window }
      assert.windows.are(known_windows)

      helpers.feed('<CR>')
      local tooltip_bufnr = vim.api.nvim_win_get_buf(helpers.wait_for_new_window(known_windows))
      assert.contents.are{
        'Type :\nType 1\n\nA type universe. `Type ≡ Type 0`, `Type u ≡ Sort (u + 1)`. ',
        bufnr = tooltip_bufnr,
      }

      -- Close the tooltip.
      helpers.feed('<Esc>')
      assert.windows.are(known_windows)
    end)

    it('does not abandon tooltips when windows are closed', function()
      vim.cmd('tabnew #')
      local tab2_window = vim.api.nvim_get_current_win()
      local tab2_infoview = infoview.get_current_infoview()
      helpers.move_cursor{ to = {1, 8} }
      helpers.wait_for_loading_pins()
      vim.api.nvim_set_current_win(tab2_infoview.window)
      helpers.move_cursor{ to = {2, 4} }  -- `Type`
      helpers.feed('<CR>')

      helpers.wait_for_new_window({ tab2_window, tab2_infoview.window })
      assert.is.equal(3, #vim.api.nvim_tabpage_list_wins(0))

      assert.is.equal(2, #vim.api.nvim_list_tabpages())

      -- Now close the other 2 windows, and the tooltip should close too.
      vim.api.nvim_win_close(tab2_infoview.window, false)
      vim.api.nvim_win_close(tab2_window, false)

      assert.is.equal(1, #vim.api.nvim_list_tabpages())
    end)
  end))

  describe('lean 3', helpers.clean_buffer('lean3', 'example : 2 = 2 := by refl', function()

    local lean_window = vim.api.nvim_get_current_win()
    local current_infoview = infoview.get_current_infoview()

    -- These tests are flaky, possibly for the same reason that 'shows a term
    -- goal' is from contents_spec. Namely, sometimes the Lean process seems to
    -- do absolutely nothing and sit there never returning a response (even an
    -- initial one). Marking these pending until we figure out what's happening
    -- there, presumably some request getting sent before the server is ready.
    it('shows widget tooltips', function(_)
      helpers.move_cursor{ to = {1, 10} }
      assert.infoview_contents.are[[
        ▶ expected type:
        ⊢ ℕ
      ]]

      vim.api.nvim_set_current_win(current_infoview.window)
      helpers.move_cursor{ to = {2, 4} }  -- `ℕ`

      local known_windows = { lean_window, current_infoview.window }
      assert.windows.are(known_windows)

      helpers.feed('<CR>')

      local tooltip_bufnr = vim.api.nvim_win_get_buf(helpers.wait_for_new_window(known_windows))

      -- x is the tooltip closer.
      assert.contents.are{ 'x Type | ℕ', bufnr = tooltip_bufnr }

      -- Close the tooltip.
      helpers.feed('<Esc>')
      vim.wait(5000, function() return #vim.api.nvim_tabpage_list_wins(0) == 2 end)
      assert.windows.are(known_windows)

      vim.api.nvim_set_current_win(lean_window)
    end)

    it('can be disabled', function(_)
      infoview.disable_widgets()
      helpers.move_cursor{ to = {1, 23} }
      helpers.wait_for_loading_pins()
      -- we're looking for `filter` to not be shown as our widget
      assert.infoview_contents.are[[
        ▶ 1 goal
        ⊢ 2 = 2
      ]]
    end)

    it('can re-enable widgets', function(_)
      infoview.enable_widgets()
      helpers.move_cursor{ to = {1, 22} }
      -- we're looking for `filter` as our widget
      -- FIXME: Extra newline only with widgets enabled
      assert.infoview_contents.are[[
        filter: no filter
        ▶ 1 goal
        ⊢ 2 = 2
      ]]
    end)
  end))
end)
