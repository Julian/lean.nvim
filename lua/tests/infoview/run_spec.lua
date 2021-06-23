local infoview = require('lean.infoview')
local get_num_wins = function() return #vim.api.nvim_list_wins() end

require('tests.helpers').setup {
  infoview = { enable = true },
  lsp = { enable = true },
  lsp3 = { enable = true },
}
describe('infoview', function()
  vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")

  local win = vim.api.nvim_get_current_win()
  local infoview_info = infoview.open()

  local function update_enabled(state, _)
    local cursor_hold = string.find(vim.api.nvim_exec("autocmd CursorHold", true), "LeanInfoviewUpdate")
    local cursor_hold_i = string.find(vim.api.nvim_exec("autocmd CursorHoldI", true), "LeanInfoviewUpdate")
    if state.mod then
      return cursor_hold and cursor_hold_i
    end
      return cursor_hold or cursor_hold_i
  end

  assert:register("assertion", "update_enabled", update_enabled)

  it('CursorHold(I) enabled when opened',
  function(_)
    assert.update_enabled()
  end)

  it('closes',
  function(_)
    assert.is_true(vim.api.nvim_win_is_valid(infoview_info.window))
    local num_wins = get_num_wins()
    infoview.close()
    assert.is_false(vim.api.nvim_win_is_valid(infoview_info.window))
    assert.is.equal(num_wins - 1, get_num_wins())
    assert.is_falsy(infoview.is_open())
  end)

  it('remains closed on BufWinEnter',
  function(_)
    infoview.close()
    local num_wins = get_num_wins()
    vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/test1.lean")
    assert.is.equal(num_wins, get_num_wins())
  end)

  it('CursorHold(I) disabled when closed',
  function(_)
    assert.is_not.update_enabled()
  end)

  it('opens',
  function(_)
    local num_wins = get_num_wins()
    infoview_info = infoview.open()
    assert.is_true(vim.api.nvim_win_is_valid(infoview_info.window))
    assert.is.equal(num_wins + 1, get_num_wins())
    assert.is_truthy(infoview.is_open())
  end)

  it('remains open on BufWinEnter',
  function(_)
    infoview_info = infoview.open()
    local num_wins = get_num_wins()
    vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/test1.lean")
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
    assert.is_falsy(infoview.is_open())
  end)

  it('manual close succeeds and updates internal state',
  function(_)
    infoview_info = infoview.open()
    local num_wins = get_num_wins()
    vim.api.nvim_set_current_win(infoview_info.window)
    vim.api.nvim_command("close")
    assert.is_false(vim.api.nvim_win_is_valid(infoview_info.window))
    assert.is.equal(num_wins - 1, get_num_wins())
    assert.is.equal(win, vim.api.nvim_get_current_win())
    assert.is_falsy(infoview.is_open())
  end)
end)
