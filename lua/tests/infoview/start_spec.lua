local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('tests.helpers').setup {}
describe('infoview', function()
  describe("startup", function()
    it('cursor stays in source window on open',
      function(_)
        vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)
        infoview.get_current_infoview():open()
        assert.win.stayed.tracked_pending()
      end)

    it('created valid infoview',
      function(_)
        assert.use_pendingwin.initopened.infoview()
      end)

    it('starts with the window position at the top',
      function(_)
        local cursor = vim.api.nvim_win_get_cursor(infoview.get_current_infoview().window)
        assert.is.same(1, cursor[1])
      end)
  end)

  describe("new tab", function()

    it('cursor stays in source window on open',
      function(_)
        vim.api.nvim_command("tabnew")
        assert.buf.created.tracked()
        assert.win.created.tracked()
        vim.api.nvim_command('edit ' .. fixtures.lean_project.some_existing_file)
        assert.initclosed.infoview()
        infoview.get_current_infoview():open()
        assert.win.stayed.tracked_pending()
      end)

    it('created valid infoview',
      function(_)
        assert.use_pendingwin.opened.infoview()
      end)

    it('starts with the window position at the top',
      function(_)
        local cursor = vim.api.nvim_win_get_cursor(infoview.get_current_infoview().window)
        assert.is.same(1, cursor[1])
      end)
  end)
end)
