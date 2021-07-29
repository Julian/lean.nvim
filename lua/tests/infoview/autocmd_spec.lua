local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('tests.helpers').setup {}
describe('infoview', function()
  local function update_enabled(state, _)
    local cursor_hold = string.find(vim.api.nvim_exec("autocmd CursorHold <buffer>", true), "LeanInfoviewUpdate")
    local cursor_hold_i = string.find(vim.api.nvim_exec("autocmd CursorHoldI <buffer>", true), "LeanInfoviewUpdate")
    if state.mod then
      return cursor_hold and cursor_hold_i
    end
      return cursor_hold or cursor_hold_i
  end

  assert:register("assertion", "update_enabled", update_enabled)

  describe('CursorHold(I)', function()
    it('enabled when opened',
    function(_)
      vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      assert.update_enabled()
    end)

    it('remains enabled on BufEnter',
    function(_)
      vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_nested_existing_file)
      assert.created_buf()
      assert.opened_infoview_kept()
      assert.update_enabled()
    end)

    it('remains enabled on WinEnter',
    function(_)
      vim.api.nvim_command('split ' .. fixtures.lean3_project.some_existing_file)
      assert.changed_buf()
      assert.created_win()
      assert.opened_infoview_kept()
      assert.update_enabled()

      vim.api.nvim_command("close")
      assert.changed_buf()
      assert.closed_win()

      vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)
      assert.changed_buf()
      assert.opened_infoview_kept()
    end)

    it('disabled when closed',
    function(_)
      infoview.get_current_infoview():close()
      assert.closed_infoview()
      assert.is_not.update_enabled()
    end)

    it('remains disabled on BufEnter',
    function(_)
      vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_nested_existing_file)
      assert.changed_buf()
      assert.closed_infoview_kept()
      assert.is_not.update_enabled()
    end)

    it('remains disabled on WinEnter',
    function(_)
      vim.api.nvim_command('split ' .. fixtures.lean3_project.some_existing_file)
      assert.changed_buf()
      assert.created_win()
      assert.closed_infoview_kept()
      assert.is_not.update_enabled()

      vim.api.nvim_command("close")
      assert.changed_buf()
      assert.closed_win()

      vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)
      assert.changed_buf()
      assert.closed_infoview_kept()
    end)

    it('re-enabled when re-opened',
    function(_)
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      assert.update_enabled()
    end)
    describe('new tab', function()
      it('disables independently',
      function(_)
        vim.api.nvim_command("tabnew")
        assert.created_buf()
        assert.created_win()
        vim.api.nvim_command("edit " .. fixtures.lean_project.some_existing_file)
        assert.kept_buf()
        assert.unopened_infoview()
        assert.is_not.update_enabled()
        vim.api.nvim_command("tabprevious")
        assert.changed_buf()
        assert.changed_win()
        assert.opened_infoview_kept()
        assert.update_enabled()
      end)

      it('enables independently',
      function(_)
        infoview.get_current_infoview():close()
        assert.closed_infoview()
        assert.is_not.update_enabled()
        vim.api.nvim_command("tabnext")
        assert.changed_buf()
        assert.changed_win()
        infoview.get_current_infoview():open()
        assert.opened_infoview()
        assert.update_enabled()
        vim.api.nvim_command("tabprevious")
        assert.changed_buf()
        assert.changed_win()
        assert.closed_infoview_kept()
        assert.is_not.update_enabled()
      end)

      it('does not enable on irrelevant file BufEnter',
      function(_)
        vim.api.nvim_command("tabnext")
        assert.changed_buf()
        assert.changed_win()
        assert.opened_infoview_kept()
        assert.update_enabled()
        vim.api.nvim_command("edit temp")
        assert.created_buf()
        assert.opened_infoview_kept()
        assert.is_not.update_enabled()
      end)

      it('does not enable when re-opening on irrelevant file',
      function(_)
        infoview.get_current_infoview():close()
        assert.closed_infoview()
        assert.is_not.update_enabled()
        infoview.get_current_infoview():open()
        assert.opened_infoview()
        assert.is_not.update_enabled()
      end)

      it('enabled on relevant file BufEnter',
      function(_)
        vim.api.nvim_command("edit " .. fixtures.lean_project.some_existing_file)
        assert.changed_buf()
        assert.opened_infoview_kept()
        assert.update_enabled()
      end)
    end)
  end)


end)
