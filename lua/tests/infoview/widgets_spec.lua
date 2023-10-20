---@brief [[
---Tests for Lean widgets (rendered inside infoviews).
---@brief ]]

local infoview = require('lean.infoview')
local helpers = require('tests.helpers')

require('lean').setup{}

describe('infoview widgets', helpers.clean_buffer('lean', '#check Nat', function()

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
