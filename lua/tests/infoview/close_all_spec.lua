local infoview = require('lean.infoview')

require('tests.helpers').setup {
  infoview = {},
}
describe('infoview', function()
  describe('close_all succeeds', function()
    it('single infoview',
    function(_)
      local info_changes = {}

      vim.api.nvim_command("edit temp.lean")
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      info_changes[vim.api.nvim_win_get_tabpage(0)] = "closed"

      infoview.close_all()

      assert.updated_infoviews(info_changes)
    end)

    it('multiple infoviews, not all opened',
    function(_)
      local info_changes = {}

      vim.api.nvim_command("tabnew")
      assert.created_win()
      vim.api.nvim_command("edit temp.lean")
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      info_changes[vim.api.nvim_win_get_tabpage(0)] = "closed"

      vim.api.nvim_command("tabnew")
      assert.created_win()
      vim.api.nvim_command("edit temp.lean")
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      info_changes[vim.api.nvim_win_get_tabpage(0)] = "closed"

      vim.api.nvim_command("tabnew")
      assert.created_win()
      vim.api.nvim_command("edit temp.lean")
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      infoview.get_current_infoview():close()
      assert.closed_infoview()
      -- can actually omit this because it would be inferred by assert.updated_infoviews()
      info_changes[vim.api.nvim_win_get_tabpage(0)] = "closed_kept"

      vim.api.nvim_command("tabnew")
      assert.created_win()
      vim.api.nvim_command("edit temp.lean")
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      info_changes[vim.api.nvim_win_get_tabpage(0)] = "closed"


      infoview.close_all()

      assert.updated_infoviews(info_changes)
    end)
  end)
end)
