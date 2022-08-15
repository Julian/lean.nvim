---@brief [[
--- Tests for infoview layout using a new tab.
---@brief ]]

require('tests.helpers')
local infoview = require('lean.infoview')

require('lean').setup{ infoview = { autoopen = false, separate_tab = true } }

describe('infoview window', function()
  it('opens in a new tab with the cursor in the Lean window', function(_)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    assert.is.equal(1, #vim.api.nvim_list_tabpages())
    local lean_window = vim.api.nvim_get_current_win()

    infoview.open()

    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    local tabpages = vim.api.nvim_list_tabpages()
    assert.is.equal(2, #tabpages)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(tabpages[2]))

    assert.is.equal(lean_window, vim.api.nvim_get_current_win())

    infoview.close()

    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    assert.is.equal(1, #vim.api.nvim_list_tabpages())
  end)
  it('repositioning has no effect', function(_)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    assert.is.equal(1, #vim.api.nvim_list_tabpages())
    local lean_window = vim.api.nvim_get_current_win()

    infoview.open()

    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    local tabpages = vim.api.nvim_list_tabpages()
    assert.is.equal(2, #tabpages)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(tabpages[2]))

    infoview.reposition()

    tabpages = vim.api.nvim_list_tabpages()
    assert.is.equal(2, #tabpages)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(tabpages[2]))

    assert.is.equal(lean_window, vim.api.nvim_get_current_win())

    infoview.close()

    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    assert.is.equal(1, #vim.api.nvim_list_tabpages())
  end)
end)
