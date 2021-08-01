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
      vim.api.nvim_command("edit " .. fixtures.lean_project.some_existing_file)
      assert.initopened.infoview()
      helpers.wait_for_ready_lsp()
      vim.api.nvim_win_set_cursor(0, {3, 23})
      helpers.wait_for_server_progress()
      infoview.__update()
      assert.info_text_changed.infoview()
      assert.has_all(infoview.get_current_info().msg, {"expected type", "⊢ Nat"})
    end)

    it('shows tactic state',
    function(_)
      vim.api.nvim_win_set_cursor(0, {6, 9})
      infoview.__update()
      assert.info_text_changed.infoview()
      assert.has_all(infoview.get_current_info().msg, {"1 goal", "p q : Prop", "h : p ∨ q", "⊢ q ∨ p"})
    end)
  end)

  describe('lean 3', function()
    it('shows term state',
    function(_)
      vim.api.nvim_command("edit " .. fixtures.lean3_project.some_nested_existing_file)
      assert.buf.created.tracked()
      helpers.wait_for_ready_lsp()
      vim.api.nvim_win_set_cursor(0, {12, 15})
      helpers.wait_for_server_progress("no goals")
      vim.api.nvim_win_set_cursor(0, {3, 23})
      infoview.__update()
      assert.info_text_changed.infoview()
      assert.has_all(infoview.get_current_info().msg, {"⊢ ℕ"})
    end)

    it('shows tactic state',
    function(_)
      vim.api.nvim_win_set_cursor(0, {7, 10})
      infoview.__update()
      assert.info_text_changed.infoview()
      assert.has_all(infoview.get_current_info().msg, {"p q : Prop", "h : p ∨ q", "⊢ q ∨ p"})
    end)

    it('only counts goals as goals, not hovered terms',
    function(_)
      -- hover for Lean 3 will also return information about `nat`, which is
      -- under the cursor, but we shouldn't count that as a goal.
      vim.api.nvim_win_set_cursor(0, {3, 14})
      infoview.__update()
      assert.info_text_changed.infoview()
      assert.equal(table.concat(infoview.get_current_info().msg, "\n"), '▶ 1 goal\n\n⊢ Type 1')
    end)
  end)

  describe('new tab', function()
    it('maintains separate infoview text',
    function(_)
      vim.api.nvim_win_set_cursor(0, {3, 23})
      infoview.__update()
      assert.info_text_changed.infoview()
      assert.has_all(infoview.get_current_info().msg, {"⊢ ℕ"})
      vim.api.nvim_command("tabnew")
      assert.win.created.tracked()
      assert.buf.created.tracked()
      vim.api.nvim_command("edit " .. fixtures.lean_project.some_existing_file)
      assert.buf.left.created({infoview.get_current_info().bufnr}).tracked()
      assert.no_buf_track.initopened.infoview()
      vim.api.nvim_win_set_cursor(0, {3, 23})
      helpers.wait_for_server_progress()
      infoview.__update()
      assert.info_text_changed.infoview()
      assert.has_all(infoview.get_current_info().msg, {"expected type", "⊢ Nat"})
      vim.api.nvim_command("tabprevious")
      assert.has_all(infoview.get_current_info().msg, {"⊢ ℕ"})
    end)
  end)
end)
