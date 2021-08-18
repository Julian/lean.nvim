local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')
local helpers = require('tests.helpers')

helpers.setup {}
describe('infoview', function()
  local function update_enabled(state, _)
    local cursor_hold = string.find(vim.api.nvim_exec("autocmd CursorMoved <buffer>", true), "LeanInfoviewUpdate")
    local cursor_hold_i = string.find(vim.api.nvim_exec("autocmd CursorMovedI <buffer>", true), "LeanInfoviewUpdate")
    if state.mod then
      return cursor_hold and cursor_hold_i
    end
      return cursor_hold or cursor_hold_i
  end

  assert:register("assertion", "update_enabled", update_enabled)

  describe('CursorMoved(I)', function()
    it('enabled when opened',
    function(_)
      helpers.edit_lean_buffer(fixtures.lean3_project.some_existing_file)
      assert.initclosed.infoview()
      infoview.get_current_infoview():open()
      assert.opened.infoview()
      assert.update_enabled()
    end)

    it('remains enabled on BufEnter',
    function(_)
      helpers.edit_lean_buffer(fixtures.lean3_project.some_nested_existing_file)
      assert.buf.created.tracked()
      assert.opened_kept.infoview()
      assert.update_enabled()
    end)

    it('remains enabled on WinEnter',
    function(_)
      vim.api.nvim_command('split')
      helpers.edit_lean_buffer(fixtures.lean3_project.some_existing_file)
      assert.buf.left.tracked()
      assert.win.created.tracked()
      assert.opened_kept.infoview()
      assert.update_enabled()

      vim.api.nvim_command("close")
      assert.buf.left.tracked()
      assert.win.removed.tracked()

      helpers.edit_lean_buffer(fixtures.lean3_project.some_existing_file)
      assert.buf.left.tracked()
      assert.opened_kept.infoview()
    end)

    it('disabled when closed',
    function(_)
      infoview.get_current_infoview():close()
      assert.closed.infoview()
      assert.is_not.update_enabled()
    end)

    it('remains disabled on BufEnter',
    function(_)
      helpers.edit_lean_buffer(fixtures.lean3_project.some_nested_existing_file)
      assert.buf.left.tracked()
      assert.closed_kept.infoview()
      assert.is_not.update_enabled()
    end)

    it('remains disabled on WinEnter',
    function(_)
      vim.api.nvim_command('split')
      helpers.edit_lean_buffer(fixtures.lean3_project.some_existing_file)
      assert.buf.left.tracked()
      assert.win.created.tracked()
      assert.closed_kept.infoview()
      assert.is_not.update_enabled()

      vim.api.nvim_command("close")
      assert.buf.left.tracked()
      assert.win.removed.tracked()

      helpers.edit_lean_buffer(fixtures.lean3_project.some_existing_file)
      assert.buf.left.tracked()
      assert.closed_kept.infoview()
    end)

    it('re-enabled when re-opened',
    function(_)
      infoview.get_current_infoview():open()
      assert.opened.infoview()
      assert.update_enabled()
    end)
    describe('new tab', function()
      it('disables independently',
      function(_)
        vim.api.nvim_command("tabnew")
        assert.buf.created.tracked()
        assert.win.created.tracked()
        helpers.edit_lean_buffer(fixtures.lean_project.some_existing_file)
        assert.initclosed.infoview()
        assert.is_not.update_enabled()
        vim.api.nvim_command("tabprevious")
        assert.buf.left.tracked()
        assert.win.left.tracked()
        assert.opened_kept.infoview()
        assert.opened_kept.infoview()
        assert.update_enabled()
      end)

      it('enables independently',
      function(_)
        infoview.get_current_infoview():close()
        assert.closed.infoview()
        assert.is_not.update_enabled()
        vim.api.nvim_command("tabnext")
        assert.buf.left.tracked()
        assert.win.left.tracked()
        infoview.get_current_infoview():open()
        assert.opened.infoview()
        assert.update_enabled()
        vim.api.nvim_command("tabprevious")
        assert.buf.left.tracked()
        assert.win.left.tracked()
        assert.closed_kept.infoview()
        assert.is_not.update_enabled()
      end)

      it('does not enable on irrelevant file BufEnter',
      function(_)
        vim.api.nvim_command("tabnext")
        assert.buf.left.tracked()
        assert.win.left.tracked()
        assert.opened_kept.infoview()
        assert.update_enabled()
        vim.api.nvim_command("edit temp")
        assert.buf.created.tracked()
        assert.opened_kept.infoview()
        assert.is_not.update_enabled()
      end)

      it('does not enable when re-opening on irrelevant file',
      function(_)
        infoview.get_current_infoview():close()
        assert.closed.infoview()
        assert.is_not.update_enabled()
        infoview.get_current_infoview():open()
        assert.opened.infoview()
        assert.is_not.update_enabled()
      end)

      it('enabled on relevant file BufEnter',
      function(_)
        helpers.edit_lean_buffer(fixtures.lean_project.some_existing_file)
        assert.buf.left.tracked()
        assert.opened_kept.infoview()
        assert.update_enabled()
      end)
    end)
  end)
end)
