local infoview = require('lean.infoview')
local get_num_wins = require('tests.helpers').get_num_wins

require('tests.helpers').setup {
  infoview = { enable = true },
}
describe('infoview', function()
  vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")

  local win = vim.api.nvim_get_current_win()
  local infoview_info = infoview.get_current_infoview():open()

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
      assert.update_enabled()
    end)

    it('closes',
    function(_)
      local num_wins = get_num_wins()
      infoview.get_current_infoview():close()
      assert.is_false(vim.api.nvim_win_is_valid(infoview_info.window))
      assert.is.equal(num_wins - 1, get_num_wins())
      assert.is_not.open_infoview()
    end)

    it('remains closed on BufEnter',
    function(_)
      local num_wins = get_num_wins()
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/test1.lean")
      assert.is.equal(num_wins, get_num_wins())
      assert.is_not.open_infoview()
    end)

    it('remains closed on WinEnter',
    function(_)
      local num_wins = get_num_wins()
      vim.api.nvim_command("split lua/tests/fixtures/example-lean3-project/test.lean")
      assert.is.equal(num_wins + 1, get_num_wins())
      assert.is_not.open_infoview()
    end)
    vim.api.nvim_command("close")

    it('CursorHold(I) disabled when closed',
    function(_)
      assert.is_not.update_enabled()
    end)

    it('opens',
    function(_)
      local num_wins = get_num_wins()
      infoview_info = infoview.get_current_infoview():open()
      assert.is_true(vim.api.nvim_win_is_valid(infoview_info.window))
      assert.is.equal(num_wins + 1, get_num_wins())
      assert.open_infoview()
    end)

    it('remains open on BufWinEnter',
    function(_)
      local num_wins = get_num_wins()
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")
      assert.is_true(vim.api.nvim_win_is_valid(infoview_info.window))
      assert.is.equal(num_wins, get_num_wins())
    end)

    it('CursorHold(I) enabled when re-opened',
    function(_)
      assert.update_enabled()
    end)

    it('manual quit succeeds and updates internal state',
    function(_)
      local num_wins = get_num_wins()
      vim.api.nvim_set_current_win(infoview_info.window)
      vim.api.nvim_command("quit")
      assert.is_false(vim.api.nvim_win_is_valid(infoview_info.window))
      assert.is.equal(num_wins - 1, get_num_wins())
      assert.is.equal(win, vim.api.nvim_get_current_win())
      assert.is_not.open_infoview()
    end)

    it('manual close succeeds and updates internal state',
    function(_)
      infoview_info = infoview.get_current_infoview():open()
      local num_wins = get_num_wins()
      vim.api.nvim_set_current_win(infoview_info.window)
      vim.api.nvim_command("close")
      assert.is_false(vim.api.nvim_win_is_valid(infoview_info.window))
      assert.is.equal(num_wins - 1, get_num_wins())
      assert.is.equal(win, vim.api.nvim_get_current_win())
      assert.is_not.open_infoview()
    end)
  end)

  infoview_info = infoview.get_current_infoview():open()

  vim.api.nvim_command("tabedit lua/tests/fixtures/example-lean4-project/Test.lean")

  local new_buf = vim.api.nvim_get_current_buf()
  local new_win = vim.api.nvim_get_current_win()
  local new_infoview_info = infoview.get_current_infoview():open()

  describe('new tab', function()
    it('closes independently',
    function(_)
      local num_wins = get_num_wins()
      infoview.get_current_infoview():close()
      assert.is_true(vim.api.nvim_win_is_valid(infoview_info.window))
      assert.is_false(vim.api.nvim_win_is_valid(new_infoview_info.window))
      assert.is.equal(num_wins - 1, get_num_wins())
      assert.is_not.open_infoview()
    end)

    it('CursorHold(I) disabled independently',
    function(_)
      assert.is_not.update_enabled()
      vim.api.nvim_set_current_win(win)
      assert.is.update_enabled()
    end)

    it('CursorHold(I) updated on BufEnter',
    function(_)
      vim.api.nvim_set_current_buf(new_buf)
      assert.is.update_enabled()
    end)

    it('CursorHold(I) updated on WinEnter',
    function(_)
      vim.api.nvim_set_current_win(new_win)
      assert.is_not.update_enabled()
    end)

    it('remains closed on BufWinEnter',
    function(_)
      local num_wins = get_num_wins()
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test/Test1.lean")
      assert.is.equal(num_wins, get_num_wins())
    end)

    it('opens independently',
    function(_)
      vim.api.nvim_set_current_win(win)
      infoview.get_current_infoview():close()
      vim.api.nvim_set_current_win(new_win)
      local num_wins = get_num_wins()
      new_infoview_info = infoview.get_current_infoview():open()
      assert.is_false(vim.api.nvim_win_is_valid(infoview_info.window))
      assert.is_true(vim.api.nvim_win_is_valid(new_infoview_info.window))
      assert.is.equal(num_wins + 1, get_num_wins())
      assert.open_infoview()
    end)

    it('remains open on BufWinEnter',
    function(_)
      local num_wins = get_num_wins()
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test/Test1.lean")
      assert.is_true(vim.api.nvim_win_is_valid(new_infoview_info.window))
      assert.is.equal(num_wins, get_num_wins())
    end)

    it('does not set CursorHold(I) on irrelevant file BufEnter',
    function(_)
      vim.api.nvim_command("edit temp")
      assert.is_not.update_enabled()
    end)

    it('does not set CursorHold(I) when re-opening on irrelevant file',
    function(_)
      infoview.get_current_infoview():close()
      new_infoview_info = infoview.get_current_infoview():open()
      assert.is_not.update_enabled()
    end)

    it('updates CursorHold(I) on relevant file BufEnter',
    function(_)
      vim.api.nvim_set_current_buf(new_buf)
      assert.update_enabled()
    end)

    vim.api.nvim_command("tabnew")
    it('opens automatically after having closen previous infoviews',
    function(_)
      local num_wins = get_num_wins()
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/test1.lean")
      assert.open_infoview()
      assert.is.equal(num_wins + 1, get_num_wins())
      assert.is.equal(2, #vim.api.nvim_tabpage_list_wins(0))
    end)

    vim.api.nvim_command("tabnew")
    infoview.set_autoopen(false)
    it('auto-open disable',
    function(_)
      local num_wins = get_num_wins()
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/test1.lean")
      assert.is_not.open_infoview()
      assert.is.equal(num_wins, get_num_wins())
      assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    end)

    it('open after auto-open disable',
    function(_)
      local num_wins = get_num_wins()
      new_infoview_info = infoview.get_current_infoview():open()
      assert.open_infoview()
      assert.is.equal(num_wins + 1, get_num_wins())
      assert.is.equal(2, #vim.api.nvim_tabpage_list_wins(0))
    end)

    it('close after auto-open disable',
    function(_)
      local num_wins = get_num_wins()
      infoview.get_current_infoview():close()
      assert.is_not.open_infoview()
      assert.is.equal(num_wins - 1, get_num_wins())
      assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    end)

    vim.api.nvim_command("tabnew")
    infoview.set_autoopen(true)
    it('auto-open enable',
    function(_)
      local num_wins = get_num_wins()
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/test1.lean")
      assert.open_infoview()
      assert.is.equal(num_wins + 1, get_num_wins())
      assert.is.equal(2, #vim.api.nvim_tabpage_list_wins(0))
    end)

    it('no auto-open for irrelevant file',
    function(_)
      local num_wins = get_num_wins()
      vim.api.nvim_command("tabedit temp")
      assert.is.equal(num_wins + 1, get_num_wins())
      assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    end)
  end)

  it('close_all succeeds',
  function(_)
    local num_wins = get_num_wins()
    infoview.close_all()

    -- should be exactly 3 open at the moment
    assert.is.equal(num_wins - 3, get_num_wins())

    for _, tab in pairs(vim.api.nvim_list_tabpages()) do
      vim.api.nvim_set_current_tabpage(tab)
      if infoview.get_current_infoview() then
        assert.is_not.open_infoview()
      end
    end
  end)
end)
