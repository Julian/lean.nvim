local infoview = require('lean.infoview')
local get_num_wins = function() return #vim.api.nvim_list_wins() end

describe('infoview', function()
  require('tests.helpers').setup {
    infoview = { enable = true },
    lsp = { enable = true },
    lsp3 = { enable = true },
  }

  vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")

  local infoview_info = infoview.open()

  it('closes',
  function(_)
    assert.is_true(vim.api.nvim_win_is_valid(infoview_info.window))
    local num_wins = get_num_wins()
    infoview.close()
    assert.is_false(vim.api.nvim_win_is_valid(infoview_info.window))
    assert.is.equal(num_wins - 1, get_num_wins())
  end)

  it('remains closed on BufWinEnter',
  function(_)
    infoview.close()
    local num_wins = get_num_wins()
    vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/test1.lean")
    assert.is.equal(num_wins, get_num_wins())
  end)

  it('opens',
  function(_)
    local num_wins = get_num_wins()
    infoview_info = infoview.open()
    assert.is_true(vim.api.nvim_win_is_valid(infoview_info.window))
    assert.is.equal(num_wins + 1, get_num_wins())
  end)

  it('remains open on BufWinEnter',
  function(_)
    infoview_info = infoview.open()
    local num_wins = get_num_wins()
    vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/test1.lean")
    assert.is_true(vim.api.nvim_win_is_valid(infoview_info.window))
    assert.is.equal(num_wins, get_num_wins())
  end)
end)
