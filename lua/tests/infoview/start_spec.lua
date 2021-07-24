local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('tests.helpers').setup { infoview = { autoopen = true } }
describe('infoview', function()
  describe("startup", function()
    local src_win = vim.api.nvim_get_current_win()
    it('created valid infoview',
      function(_)
        vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)
        assert.open_infoview()
      end)

    it('starts with the window position at the top',
      function(_)
        local cursor = vim.api.nvim_win_get_cursor(infoview.get_current_infoview().window)
        assert.is.same(1, cursor[1])
      end)

    it('cursor starts in source window',
      function(_)
        assert.is.same(src_win, vim.api.nvim_get_current_win())
      end)
  end)

  describe("new tab", function()
    local src_win

    it('created valid distinct infoview',
      function(_)
        vim.api.nvim_command("tabnew")
        assert.new_win()
        src_win = vim.api.nvim_get_current_win()
        vim.api.nvim_command('edit ' .. fixtures.lean_project.some_existing_file)
        assert.open_infoview()
      end)

    it('starts with the window position at the top',
      function(_)
        local cursor = vim.api.nvim_win_get_cursor(infoview.get_current_infoview().window)
        assert.is.same(1, cursor[1])
      end)

    it('cursor starts in source window',
      function(_)
        assert.is.same(src_win, vim.api.nvim_get_current_win())
      end)
  end)
end)
