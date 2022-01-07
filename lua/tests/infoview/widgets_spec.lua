---@brief [[
---Tests for Lean widgets (rendered inside infoviews).
---@brief ]]

local infoview = require('lean.infoview')
local helpers = require('tests.helpers')

require('lean').setup{}

describe('infoview enable/disable_widgets', function()
  describe('lean 4', helpers.clean_buffer('lean', '#check Nat', function()

    local lean_window = vim.api.nvim_get_current_win()
    local current_infoview = infoview.get_current_infoview()

    it('shows widget tooltips', function(_)
      helpers.move_cursor{ to = {1, 8} }
      helpers.wait_for_infoview_contents('Nat')
      assert.infoview_contents.are[[
        ▶ expected type (1:8-1:11)
        ⊢ Type

        ▶ 1:1-1:7: information:
        Nat : Type
      ]]

      vim.api.nvim_set_current_win(current_infoview.window)
      helpers.move_cursor{ to = {2, 4} }  -- `Type`

      assert.are.same_elements(
        { lean_window, current_infoview.window },
        vim.api.nvim_tabpage_list_wins(0)
      )
      helpers.feed("<CR>")

      local tooltip_bufnr
      vim.wait(1000, function()
        for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if window ~= lean_window and window ~= current_infoview.window then
            tooltip_bufnr = vim.api.nvim_win_get_buf(window)
            return true
          end
        end
      end)

      assert.contents.are{ 'Type :\nType 1', bufnr = tooltip_bufnr }

      -- Close the tooltip.
      helpers.feed("<Esc>")
      assert.are.same_elements(
        { lean_window, current_infoview.window },
        vim.api.nvim_tabpage_list_wins(0)
      )
    end)
  end))

  describe('lean 3', helpers.clean_buffer('lean3', 'example : 2 = 2 := by refl', function()
    -- These tests are flaky, possibly for the same reason that 'shows a term
    -- goal' is from contents_spec. Namely, sometimes the Lean process seems to
    -- do absolutely nothing and sit there never returning a response (even an
    -- initial one). Marking these pending until we figure out what's happening
    -- there, presumably some request getting sent before the server is ready.
    pending('can be disabled', function(_)
      helpers.wait_for_ready_lsp()
      infoview.disable_widgets()
      helpers.move_cursor{ to = {1, 22} }
      helpers.wait_for_infoview_contents('2 = 2')
      -- we're looking for `filter` to not be shown as our widget
      assert.infoview_contents.are[[
        ▶ 1 goal
        ⊢ 2 = 2
      ]]
    end)

    pending('can re-enable widgets', function(_)
      infoview.enable_widgets()
      helpers.move_cursor{ to = {1, 22} }
      helpers.wait_for_infoview_contents('filter')
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
