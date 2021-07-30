local infoview = require('lean.infoview')

require('tests.helpers').setup {
  infoview = {},
}
describe('infoview', function()
  describe('close_all succeeds', function()
    it('single infoview',
    function(_)
      vim.api.nvim_command("edit temp.lean")
      infoview.get_current_infoview():open()
      assert.opened.infoview()

      infoview.close_all()

      assert.closed.infoview()
    end)

    it('multiple infoviews, not all opened',
    function(_)
      vim.api.nvim_command("tabnew")
      assert.buf.created.tracked()
      assert.win.created.tracked()
      vim.api.nvim_command("edit temp.lean")
      assert.buf.left.tracked()
      assert.win.stayed.tracked()
      infoview.get_current_infoview():open()
      assert.opened.infoview()
      local tab1 = vim.api.nvim_win_get_tabpage(0)

      vim.api.nvim_command("tabnew")
      assert.buf.created.tracked()
      assert.win.created.tracked()
      vim.api.nvim_command("edit temp.lean")
      assert.buf.left.tracked()
      assert.win.stayed.tracked()
      infoview.get_current_infoview():open()
      assert.opened.infoview()
      local tab2 = vim.api.nvim_win_get_tabpage(0)

      vim.api.nvim_command("tabnew")
      assert.buf.created.tracked()
      assert.win.created.tracked()
      vim.api.nvim_command("edit temp.lean")
      assert.buf.left.tracked()
      assert.win.stayed.tracked()
      infoview.get_current_infoview():open()
      assert.opened.infoview()
      infoview.get_current_infoview():close()
      assert.closed_infoview()
      local tab3 = vim.api.nvim_win_get_tabpage(0)

      vim.api.nvim_command("tabnew")
      assert.buf.created.tracked()
      assert.win.created.tracked()
      vim.api.nvim_command("edit temp.lean")
      assert.buf.left.tracked()
      assert.win.stayed.tracked()
      infoview.get_current_infoview():open()
      assert.opened.infoview()
      local tab4 = vim.api.nvim_win_get_tabpage(0)

      infoview.close_all()

      assert.closed({tab1, tab2, tab4}).closed_kept({tab3}).infoview()
    end)
  end)
end)
