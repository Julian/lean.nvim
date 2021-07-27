local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('tests.helpers').setup{}
describe('infoview', function()
  describe('initial', function()
    it('opens',
    function(_)
      vim.api.nvim_command("edit " .. fixtures.lean3_project.some_existing_file)
      infoview.get_current_infoview():open()
      assert.opened_infoview()
    end)

    it('remains open on BufEnter',
    function(_)
      vim.api.nvim_command("edit " .. fixtures.lean3_project.some_existing_file)
      assert.opened_infoview_kept()
    end)

    it('remains open on WinEnter',
    function(_)
      vim.api.nvim_command("split " .. fixtures.lean3_project.some_existing_file)
      assert.created_win()
      assert.opened_infoview_kept()
      vim.api.nvim_command("close")
      assert.closed_win()
      assert.opened_infoview_kept()
    end)

    it('closes',
    function(_)
      vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)
      assert.opened_infoview_kept()
      infoview.get_current_infoview():close()
      assert.closed_infoview()
    end)

    it('remains closed on BufEnter',
    function(_)
      vim.api.nvim_command("edit " .. fixtures.lean3_project.some_nested_existing_file)
      -- would be equivalent to just do assert.updated_infoviews() here, because this would
      -- correctly infer closed_infoview_kept; kept it (and others like it) for readability
      assert.closed_infoview_kept()
    end)

    it('remains closed on WinEnter',
    function(_)
      vim.api.nvim_command("split " .. fixtures.lean3_project.some_existing_file)
      assert.created_win()
      assert.closed_infoview_kept()
      vim.api.nvim_command("close")
      assert.closed_win()
      assert.closed_infoview_kept()
    end)

    it('manual quit succeeds and updates internal state',
    function(_)
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      vim.api.nvim_command("wincmd l")
      assert.changed_win()
      vim.api.nvim_command("quit")
      assert.closed_infoview()
    end)

    it('manual close succeeds and updates internal state',
    function(_)
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      vim.api.nvim_command("wincmd l")
      assert.changed_win()
      vim.api.nvim_command("close")
      assert.closed_infoview()
    end)
  end)

  describe('new tab', function()
    it('closes independently',
    function(_)
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      vim.api.nvim_command("tabnew")
      assert.created_win()
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test.lean")
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      infoview.get_current_infoview():close()
      assert.closed_infoview()
      vim.api.nvim_command("tabprevious")
      assert.changed_win()
      assert.opened_infoview_kept()
    end)

    it('opens independently',
    function(_)
      infoview.get_current_infoview():close()
      assert.closed_infoview()
      vim.api.nvim_command("tabnext")
      assert.changed_win()
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      vim.api.nvim_command("tabprevious")
      assert.changed_win()
      assert.closed_infoview_kept()
      vim.api.nvim_command("tabnext")
      assert.changed_win()
      assert.opened_infoview_kept()
    end)
  end)
end)
