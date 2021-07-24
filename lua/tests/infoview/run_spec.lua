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
      assert.open_infoview()
      assert.update_enabled()
    end)

    it('closes',
    function(_)
      infoview.get_current_infoview():close()
      assert.is_not.open_infoview()
    end)

    it('remains closed on BufEnter',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/test1.lean")
      assert.is_not.open_infoview(true)
    end)

    it('remains closed on WinEnter',
    function(_)
      vim.api.nvim_command("split lua/tests/fixtures/example-lean3-project/test.lean")
      assert.new_win()
      assert.is_not.open_infoview(true)
      vim.api.nvim_command("close")
      assert.close_win()
    end)

    it('CursorHold(I) disabled when closed',
    function(_)
      assert.is_not.update_enabled()
    end)

    it('opens',
    function(_)
      infoview.get_current_infoview():open()
      assert.open_infoview()
    end)

    it('remains open on BufWinEnter',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")
      assert.open_infoview(true)
    end)

    it('CursorHold(I) enabled when re-opened',
    function(_)
      assert.update_enabled()
    end)

    it('manual quit succeeds and updates internal state',
    function(_)
      vim.api.nvim_command("wincmd l")
      vim.api.nvim_command("quit")
      assert.is_not.open_infoview()
    end)

    it('manual close succeeds and updates internal state',
    function(_)
      infoview.get_current_infoview():open()
      assert.open_infoview()
      vim.api.nvim_command("wincmd l")
      vim.api.nvim_command("close")
      assert.is_not.open_infoview()
    end)
  end)

  describe('new tab', function()
    it('closes independently',
    function(_)
      infoview.get_current_infoview():open()
      assert.open_infoview()
      vim.api.nvim_command("tabnew")
      assert.new_win()
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test.lean")
      assert.open_infoview()
      infoview.get_current_infoview():close()
      assert.is_not.open_infoview()
      assert.is_not.update_enabled()
      vim.api.nvim_command("tabprevious")
      assert.change_infoview()
      assert.open_infoview(true)
    end)

    it('CursorHold(I) disabled independently',
    function(_)
      assert.is.update_enabled()
    end)

    it('CursorHold(I) updated on BufEnter',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test.lean")
      assert.open_infoview(true)
      assert.is.update_enabled()
    end)

    it('CursorHold(I) updated on WinEnter',
    function(_)
      vim.api.nvim_command("tabnext")
      assert.change_infoview()
      assert.is_not.open_infoview(true)
      assert.is_not.update_enabled()
    end)

    it('remains closed on BufWinEnter',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test/Test1.lean")
      assert.is_not.open_infoview(true)
    end)

    it('opens independently',
    function(_)
      vim.api.nvim_command("tabprevious")
      assert.change_infoview()
      infoview.get_current_infoview():close()
      assert.is_not.open_infoview()
      vim.api.nvim_command("tabnext")
      assert.change_infoview()
      infoview.get_current_infoview():open()
      assert.open_infoview()
      vim.api.nvim_command("tabprevious")
      assert.change_infoview()
      assert.is_not.open_infoview(true)
      vim.api.nvim_command("tabnext")
      assert.change_infoview()
      assert.open_infoview(true)
    end)

    it('remains open on BufWinEnter',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test/Test1.lean")
      assert.open_infoview(true)
    end)

    it('does not set CursorHold(I) on irrelevant file BufEnter',
    function(_)
      vim.api.nvim_command("edit temp")
      assert.open_infoview(true)
      assert.is_not.update_enabled()
    end)

    it('does not set CursorHold(I) when re-opening on irrelevant file',
    function(_)
      infoview.get_current_infoview():close()
      assert.is_not.open_infoview()
      infoview.get_current_infoview():open()
      assert.open_infoview()
      assert.is_not.update_enabled()
    end)

    it('updates CursorHold(I) on relevant file BufEnter',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test/Test1.lean")
      assert.update_enabled()
    end)
  end)
end)
