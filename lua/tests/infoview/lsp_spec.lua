local infoview = require('lean.infoview')
local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')

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
      vim.api.nvim_win_set_cursor(0, {3, 23})
      helpers.wait_for_server_progress()
      infoview.__update()
      assert.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.msg, {"expected type", "⊢ Nat"})
    end)

    it('shows tactic state',
    function(_)
      vim.api.nvim_win_set_cursor(0, {6, 9})
      infoview.__update()
      assert.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.msg, {"1 goal", "p q : Prop", "h : p ∨ q", "⊢ q ∨ p"})
    end)

    pending('re-issues on ContentModified',
    function(_)
      vim.api.nvim_win_set_cursor(0, {16, 1})
      vim.api.nvim_buf_set_lines(0, 14, 15, true, {"def new_test : Prop := by"})
      infoview.__update()
      vim.api.nvim_buf_set_lines(0, 14, 15, true, {"def new_test : Nat := by"})
      assert.info_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.msg, {"1 goal\n\n⊢ Nat"})
    end)
  end)

  describe('lean 3', function()
    it('shows term state',
    function(_)
      helpers.edit_lean_buffer(fixtures.lean3_project.some_nested_existing_file)
      assert.buf.created.tracked_pending()
      assert.use_pendingbuf.pin_text_changed.infoview()
      helpers.wait_for_ready_lsp()
      vim.api.nvim_win_set_cursor(0, {12, 13})
      helpers.wait_for_server_progress("assumption")
      vim.api.nvim_win_set_cursor(0, {3, 23})
      infoview.__update()
      assert.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.msg, {"⊢ ℕ"})
    end)

    it('shows tactic state',
    function(_)
      vim.api.nvim_win_set_cursor(0, {7, 10})
      infoview.__update()
      assert.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.msg, {"p q : Prop", "h : p ∨ q", "⊢ q ∨ p"})
    end)

    it('only counts goals as goals, not hovered terms',
    function(_)
      -- hover for Lean 3 will also return information about `nat`, which is
      -- under the cursor, but we shouldn't count that as a goal.
      vim.api.nvim_win_set_cursor(0, {3, 14})
      infoview.__update()
      assert.pin_text_changed.infoview()
      assert.equal(table.concat(infoview.get_current_infoview().info.pin.msg, "\n"), '▶ 1 goal\n\n⊢ Type 1')
    end)
  end)

  describe('new tab', function()
    it('maintains separate infoview text',
    function(_)
      vim.api.nvim_win_set_cursor(0, {3, 23})
      infoview.__update()
      assert.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.msg, {"⊢ ℕ"})
      vim.api.nvim_command("tabnew")
      assert.win.created.tracked()
      assert.buf.created.tracked()
      helpers.edit_lean_buffer(fixtures.lean_project.some_existing_file)
      assert.buf.left.tracked_pending()
      assert.use_pendingbuf.initopened.infoview()
      vim.api.nvim_win_set_cursor(0, {3, 23})
      helpers.wait_for_server_progress()
      infoview.__update()
      assert.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.msg, {"expected type", "⊢ Nat"})
      vim.api.nvim_command("tabprevious")
      assert.has_all(infoview.get_current_infoview().info.pin.msg, {"⊢ ℕ"})
    end)
  end)
end)
