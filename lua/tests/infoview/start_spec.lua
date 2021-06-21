local infoview = require('lean.infoview')
local get_num_wins = function() return #vim.api.nvim_list_wins() end

require('tests.helpers').setup { infoview = { enable = true } }
describe('infoview', function()
  describe("startup", function()
    local src_win = vim.api.nvim_get_current_win()
    local num_wins = get_num_wins()
    it('automatically opens',
      function(_)
        vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")
        assert.is_true(infoview.is_open())
        assert.is.equal(num_wins + 1, get_num_wins())
        assert.is.equal(2, #vim.api.nvim_tabpage_list_wins(0))
      end)

    local infoview_info = infoview.open()

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

  local orig_infoview_info = infoview.open()

  vim.api.nvim_command("tabnew")
  describe("new tab", function()
    local src_win = vim.api.nvim_get_current_win()
    local num_wins = get_num_wins()
    it('automatically opens',
      function(_)
        vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test.lean")
        assert.is_true(infoview.is_open())
        assert.is.equal(num_wins + 1, get_num_wins())
        assert.is.equal(2, #vim.api.nvim_tabpage_list_wins(0))
      end)

    local infoview_info = infoview.open()

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

  infoview.close()
end)
