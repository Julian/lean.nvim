local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('tests.helpers').setup { infoview = { autoopen = true } }
describe('infoview', function()
  describe("startup", function()
    local src_win = vim.api.nvim_get_current_win()
    vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)
    local infoview_info = infoview.get_current_infoview():open()

    it('created valid infoview',
      function(_)
        assert.is_true(vim.api.nvim_win_is_valid(infoview_info.window))
        assert.is_true(vim.api.nvim_buf_is_valid(infoview_info.bufnr))
      end)

    it('starts with the window position at the top',
      function(_)
        local cursor = vim.api.nvim_win_get_cursor(infoview_info.window)
        assert.is.same(1, cursor[1])
      end)

    it('cursor starts in source window',
      function(_)
        assert.is.same(src_win, vim.api.nvim_get_current_win())
      end)
  end)

  local orig_infoview_info = infoview.get_current_infoview():open()

  vim.api.nvim_command("tabnew")
  describe("new tab", function()
    local src_win = vim.api.nvim_get_current_win()
    vim.api.nvim_command('edit ' .. fixtures.lean_project.some_existing_file)
    local infoview_info = infoview.get_current_infoview():open()

    it('created valid distinct infoview',
      function(_)
        assert.is_true(vim.api.nvim_win_is_valid(infoview_info.window))
        assert.is_true(vim.api.nvim_buf_is_valid(infoview_info.bufnr))
        assert.are_not.equal(orig_infoview_info.bufnr, infoview_info.bufnr)
        assert.are_not.equal(orig_infoview_info.window, infoview_info.window)
      end)

    it('starts with the window position at the top',
      function(_)
        local cursor = vim.api.nvim_win_get_cursor(infoview_info.window)
        assert.is.same(1, cursor[1])
      end)

    it('cursor starts in source window',
      function(_)
        assert.is.same(src_win, vim.api.nvim_get_current_win())
      end)
  end)

  infoview.get_current_infoview():close()
end)
