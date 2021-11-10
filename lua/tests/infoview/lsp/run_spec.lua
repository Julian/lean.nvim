local infoview = require('lean.infoview')
local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')
local position = require('vim.lsp.util').make_position_params

helpers.setup {
  infoview = { autoopen = true },
  lsp = { enable = true },
  lsp3 = { enable = true },
}

describe('infoview', function()
  describe('lean 4', function()
    it('shows term state',
    function(_)
      helpers.edit_lean_buffer(fixtures.lean_project.some_existing_file)
      assert.initopened.infoview()
      helpers.wait_for_ready_lsp()
      helpers.wait_for_server_progress()
      vim.api.nvim_win_set_cursor(0, {3, 23})
      infoview.get_current_infoview().info.pin:set_position_params(position())
      infoview.get_current_infoview().info.pin:update(true)
      assert.pin_pos_changed.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.div:to_string(), {"expected type", "⊢ Nat"})
    end)

    it('shows tactic state',
    function(_)
      vim.api.nvim_win_set_cursor(0, {6, 9})
      infoview.get_current_infoview().info.pin:set_position_params(position())
      infoview.get_current_infoview().info.pin:update(true)
      assert.pin_pos_changed.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.div:to_string(),
        {"1 goal", "p q : Prop", "h : p ∨ q", "⊢ q ∨ p"})
    end)

    if vim.version().minor == 6 then
      it('re-issues on ContentModified',
      function(_)
        vim.api.nvim_win_set_cursor(0, {16, 1})
        infoview.get_current_infoview().info.pin:set_position_params(position())
        vim.api.nvim_buf_set_lines(0, 14, 15, true, {"def new_test : Prop := by"})
        infoview.get_current_infoview().info.pin:update(true, 0)
        vim.api.nvim_buf_set_lines(0, 14, 15, true, {"def new_test : Nat := by"})
        assert.pin_pos_changed.pin_text_changed.infoview()
        assert.has_all(infoview.get_current_infoview().info.pin.div:to_string(), {"1 goal\n⊢ Nat"})
      end)
    end
  end)

  describe('lean 3', function()
    it('shows term state',
    function(_)
      helpers.edit_lean_buffer(fixtures.lean3_project.some_nested_existing_file)
      assert.buf.created.tracked_pending()
      assert.use_pendingbuf.pin_pos_changed.infoview()
      helpers.wait_for_ready_lsp()
      vim.api.nvim_win_set_cursor(0, {12, 13})
      helpers.wait_for_server_progress("assumption")
      vim.api.nvim_win_set_cursor(0, {3, 23})
      infoview.get_current_infoview().info.pin:set_position_params(position())
      infoview.get_current_infoview().info.pin:update(true)
      assert.pin_pos_changed.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.div:to_string(), {"⊢ ℕ"})
    end)

    it('shows tactic state',
    function(_)
      vim.api.nvim_win_set_cursor(0, {7, 10})
      infoview.get_current_infoview().info.pin:set_position_params(position())
      infoview.get_current_infoview().info.pin:update(true)
      assert.pin_pos_changed.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.div:to_string(), {"p q : Prop", "h : p ∨ q", "⊢ q ∨ p"})
    end)

    it('only counts goals as goals, not hovered terms',
    function(_)
      -- hover for Lean 3 will also return information about `nat`, which is
      -- under the cursor, but we shouldn't count that as a goal.
      vim.api.nvim_win_set_cursor(0, {3, 14})
      infoview.get_current_infoview().info.pin:set_position_params(position())
      infoview.get_current_infoview().info.pin:update(true)
      assert.pin_pos_changed.pin_text_changed.infoview()
      assert.equal(infoview.get_current_infoview().info.pin.div:to_string(),
      '▶ expected type:\n⊢ Type 1')
    end)
  end)

  describe('new tab', function()
    it('maintains separate infoview text',
    function(_)
      vim.api.nvim_win_set_cursor(0, {3, 23})
      infoview.get_current_infoview().info.pin:set_position_params(position())
      infoview.get_current_infoview().info.pin:update(true)
      assert.pin_pos_changed.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.div:to_string(), {"⊢ ℕ"})
      vim.api.nvim_command("tabnew")
      assert.win.created.tracked()
      assert.buf.created.tracked()
      helpers.edit_lean_buffer(fixtures.lean_project.some_existing_file)
      assert.buf.left.tracked_pending()
      assert.use_pendingbuf.initopened.infoview()
      vim.api.nvim_win_set_cursor(0, {3, 23})
      helpers.wait_for_server_progress()
      infoview.get_current_infoview().info.pin:set_position_params(position())
      infoview.get_current_infoview().info.pin:update(true)
      assert.pin_pos_changed.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.div:to_string(), {"expected type", "⊢ Nat"})
      vim.api.nvim_command("tabprevious")
      assert.win.left.tracked_pending()
      assert.buf.left.tracked_pending()
      assert.use_pendingbuf.use_pendingwin.pin_text_kept.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.div:to_string(), {"⊢ ℕ"})
    end)
  end)
end)
