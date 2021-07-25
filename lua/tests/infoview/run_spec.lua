local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('tests.helpers').setup {
  infoview = { autoopen = true },
}
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

  describe('initial', function()
    it('CursorHold(I) enabled when opened',
    function(_)
      vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)
      assert.opened_infoview()
      assert.update_enabled()
    end)

    it('closes',
    function(_)
      infoview.get_current_infoview():close()
      assert.closed_infoview()
    end)

    it('remains closed on BufEnter',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/test1.lean")
      -- would be equivalent to just do assert.updated_infoviews() here, because this would
      -- correctly infer closed_infoview_kept; kept it (and others like it) for readability
      assert.closed_infoview_kept()
    end)

    it('remains closed on WinEnter',
    function(_)
      vim.api.nvim_command("split lua/tests/fixtures/example-lean3-project/test.lean")
      assert.created_win()
      assert.closed_infoview_kept()
      vim.api.nvim_command("close")
      assert.closed_win()
    end)

    it('CursorHold(I) disabled when closed',
    function(_)
      assert.is_not.update_enabled()
    end)

    it('opens',
    function(_)
      infoview.get_current_infoview():open()
      assert.opened_infoview()
    end)

    it('remains open on BufWinEnter',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")
      assert.opened_infoview_kept()
    end)

    it('CursorHold(I) enabled when re-opened',
    function(_)
      assert.update_enabled()
    end)

    it('manual quit succeeds and updates internal state',
    function(_)
      vim.api.nvim_command("wincmd l")
      vim.api.nvim_command("quit")
      assert.closed_infoview()
    end)

    it('manual close succeeds and updates internal state',
    function(_)
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      vim.api.nvim_command("wincmd l")
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
      assert.opened_infoview()
      infoview.get_current_infoview():close()
      assert.closed_infoview()
      assert.is_not.update_enabled()
      vim.api.nvim_command("tabprevious")
      assert.opened_infoview_kept()
    end)

    it('CursorHold(I) disabled independently',
    function(_)
      assert.is.update_enabled()
    end)

    it('CursorHold(I) updated on BufEnter',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test.lean")
      assert.opened_infoview_kept()
      assert.is.update_enabled()
    end)

    it('CursorHold(I) updated on WinEnter',
    function(_)
      vim.api.nvim_command("tabnext")
      assert.closed_infoview_kept()
      assert.is_not.update_enabled()
    end)

    it('remains closed on BufWinEnter',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test/Test1.lean")
      assert.closed_infoview_kept()
    end)

    it('opens independently',
    function(_)
      vim.api.nvim_command("tabprevious")
      infoview.get_current_infoview():close()
      assert.closed_infoview()
      vim.api.nvim_command("tabnext")
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      vim.api.nvim_command("tabprevious")
      assert.closed_infoview_kept()
      vim.api.nvim_command("tabnext")
      assert.opened_infoview_kept()
    end)

    it('remains open on BufWinEnter',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test/Test1.lean")
      assert.opened_infoview_kept()
    end)

    it('does not set CursorHold(I) on irrelevant file BufEnter',
    function(_)
      vim.api.nvim_command("edit temp")
      assert.opened_infoview_kept()
      assert.is_not.update_enabled()
    end)

    it('does not set CursorHold(I) when re-opening on irrelevant file',
    function(_)
      infoview.get_current_infoview():close()
      assert.closed_infoview()
      infoview.get_current_infoview():open()
      assert.opened_infoview()
      assert.is_not.update_enabled()
    end)

    it('updates CursorHold(I) on relevant file BufEnter',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test/Test1.lean")
      assert.update_enabled()
    end)
  end)
end)
