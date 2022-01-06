require('tests.helpers')
local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('lean').setup{ infoview = { autoopen = true } }

describe('infoview autoopen', function()
  -- Somewhat follows open_close_spec.lua but here infoviews open automatically

  local lean_window

  it('automatically opens infoviews when editing new Lean files', function(_)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    vim.cmd('edit! ' .. fixtures.lean3_project.some_existing_file)
    lean_window = vim.api.nvim_get_current_win()
    assert.are.same_elements(
      { lean_window, infoview.get_current_infoview().window },
      vim.api.nvim_tabpage_list_wins(0)
    )
  end)

  it('reuses the same infoview for new Lean files in the same tab', function(_)
    local windows = vim.api.nvim_tabpage_list_wins(0)
    assert.is.equal(#windows, 2)  -- +1 above
    assert.is.truthy(
      vim.tbl_contains(windows, infoview.get_current_infoview().window)
    )

    vim.cmd('split ' .. fixtures.lean3_project.some_nested_existing_file)
    table.insert(windows, vim.api.nvim_get_current_win())
    assert.are.same_elements(windows, vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('quit')
  end)

  it('automatically opens additional infoviews for new tabs', function(_)
    local tab1_infoview = infoview.get_current_infoview()

    vim.cmd('tabnew')
    local tab2_window = vim.api.nvim_get_current_win()
    assert.are.same({ tab2_window }, vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('edit! ' .. fixtures.lean3_project.some_nested_existing_file)
    local tab2_infoview = infoview.get_current_infoview()
    assert.are_not.same(tab1_infoview, tab2_infoview)

    assert.same.elements(
      { tab2_window, tab2_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    vim.cmd('tabclose')
  end)

  it('does not (auto-)open infoviews for non-Lean files', function(_)
    vim.cmd('tabnew')
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('edit some_other_file.foo')
    local non_lean_window = vim.api.nvim_get_current_win()

    assert.are.same({ non_lean_window }, vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('tabclose')
  end)

  it('does not auto-reopen an infoview that has been closed', function(_)
    local windows = vim.api.nvim_tabpage_list_wins(0)
    assert.is.equal(#windows, 2)  -- +1 above
    assert.is.truthy(
      vim.tbl_contains(windows, infoview.get_current_infoview().window)
    )

    infoview.get_current_infoview():close()
    assert.is.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('split ' .. fixtures.lean3_project.some_nested_existing_file)
    assert.are.same_elements(
      { lean_window, vim.api.nvim_get_current_win() },
      vim.api.nvim_tabpage_list_wins(0)
    )

    vim.cmd('quit')
  end)

  it('allows infoviews to reopen manually after closing', function(_)
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))
    local closed_infoview = infoview.get_current_infoview()
    closed_infoview:open()
    assert.are.same_elements(
      { lean_window, closed_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )
  end)

  it('can be disabled', function(_)
    vim.cmd('tabnew')
    infoview.set_autoopen(false)
    local tab2_window = vim.api.nvim_get_current_win()
    vim.cmd('edit! ' .. fixtures.lean3_project.some_nested_existing_file)
    assert.is.same({ tab2_window }, vim.api.nvim_tabpage_list_wins(0))

    -- But windows can still be opened and closed manually
    local tab2_infoview = infoview.get_current_infoview()
    tab2_infoview:open()
    assert.same.elements(
      { tab2_window, tab2_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    tab2_infoview:close()
    assert.is.same({ tab2_window }, vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('tabclose')
  end)

  it('can be re-enabled after being disabled', function(_)
    infoview.set_autoopen(false)
    infoview.set_autoopen(true)

    vim.api.nvim_command('tabnew')
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    vim.cmd('edit! ' .. fixtures.lean3_project.some_existing_file)
    local current_window = vim.api.nvim_get_current_win()
    assert.are.same_elements(
      { current_window, infoview.get_current_infoview().window },
      vim.api.nvim_tabpage_list_wins(0)
    )
  end)
end)
