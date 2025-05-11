local Tab = require 'std.nvim.tab'
local Window = require 'std.nvim.window'

require 'spec.helpers'
local fixtures = require 'spec.fixtures'
local infoview = require 'lean.infoview'

require('lean').setup { infoview = { autoopen = true } }

describe('infoview autoopen', function()
  -- Somewhat follows open_close_spec.lua but here infoviews open automatically

  local lean_window

  it('automatically opens infoviews when editing new Lean files', function()
    assert.is.equal(1, #Tab:current():windows())
    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    lean_window = Window:current()
    assert.windows.are(lean_window.id, infoview.get_current_infoview().window)
  end)

  it('reuses the same infoview for new Lean files in the same tab', function()
    local windows = vim.api.nvim_tabpage_list_wins(0)
    assert.is.equal(#windows, 2) -- +1 above
    assert.is.truthy(vim.tbl_contains(windows, infoview.get_current_infoview().window))

    vim.cmd.split(fixtures.project.some_nested_existing_file)
    table.insert(windows, vim.api.nvim_get_current_win())
    assert.windows.are(windows)

    vim.cmd.quit()
  end)

  it('automatically opens additional infoviews for new tabs', function()
    local tab1_infoview = infoview.get_current_infoview()

    vim.cmd.tabnew()
    local tab2_window = vim.api.nvim_get_current_win()
    assert.windows.are(tab2_window)

    vim.cmd.edit { fixtures.project.some_nested_existing_file, bang = true }
    local tab2_infoview = infoview.get_current_infoview()
    assert.are_not.same(tab1_infoview, tab2_infoview)

    assert.windows.are(tab2_window, tab2_infoview.window)

    vim.cmd.tabclose()
  end)

  it('does not (auto-)open infoviews for non-Lean files', function()
    vim.cmd.tabnew()
    assert.is.equal(1, #Tab:current():windows())

    vim.cmd.edit 'some_other_file.foo'
    local non_lean_window = Window:current()

    assert.windows.are(non_lean_window.id)

    vim.cmd.tabclose()
  end)

  it('does not auto-reopen an infoview that has been closed', function()
    local windows = vim.api.nvim_tabpage_list_wins(0)
    assert.is.equal(#windows, 2) -- +1 above
    assert.is.truthy(vim.tbl_contains(windows, infoview.get_current_infoview().window))

    infoview.close()
    assert.windows.are(lean_window.id)

    vim.cmd.split(fixtures.project.some_nested_existing_file)
    assert.windows.are(lean_window.id, vim.api.nvim_get_current_win())

    vim.cmd.quit()
  end)

  it('allows infoviews to reopen manually after closing', function()
    assert.windows.are(lean_window.id)
    local reopened_infoview = infoview.open()
    assert.windows.are(lean_window.id, reopened_infoview.window)
  end)

  it('can be disabled', function()
    vim.cmd.tabnew()
    infoview.set_autoopen(false)
    local tab2_window = vim.api.nvim_get_current_win()
    vim.cmd.edit { fixtures.project.some_nested_existing_file, bang = true }
    assert.windows.are(tab2_window)

    -- But windows can still be opened and closed manually
    local tab2_infoview = infoview.open()
    assert.windows.are(tab2_window, tab2_infoview.window)

    tab2_infoview:close()
    assert.windows.are(tab2_window)

    vim.cmd.tabclose()
  end)

  it('can be re-enabled after being disabled', function()
    infoview.set_autoopen(false)
    infoview.set_autoopen(true)

    vim.cmd.tabnew()
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    local current_window = vim.api.nvim_get_current_win()
    assert.windows.are(current_window, infoview.get_current_infoview().window)
  end)
end)
