---@brief [[
--- Tests for infoview layout using a new tab.
---@brief ]]

local Window = require 'std.nvim.window'

require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup { infoview = { autoopen = false, separate_tab = true } }

describe('infoview window', function()
  it('opens in a new tab with the cursor in the Lean window', function()
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    assert.is.equal(1, #vim.api.nvim_list_tabpages())
    local lean_window = Window:current()

    infoview.open()

    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    local tabpages = vim.api.nvim_list_tabpages()
    assert.is.equal(2, #tabpages)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(tabpages[2]))

    assert.current_window.is(lean_window)

    infoview.close()

    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    assert.is.equal(1, #vim.api.nvim_list_tabpages())
  end)
  it('repositioning has no effect', function()
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    assert.is.equal(1, #vim.api.nvim_list_tabpages())
    local lean_window = Window:current()

    infoview.open()

    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    local tabpages = vim.api.nvim_list_tabpages()
    assert.is.equal(2, #tabpages)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(tabpages[2]))

    infoview.reposition()

    tabpages = vim.api.nvim_list_tabpages()
    assert.is.equal(2, #tabpages)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(tabpages[2]))

    assert.current_window.is(lean_window)

    infoview.close()

    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    assert.is.equal(1, #vim.api.nvim_list_tabpages())
  end)
end)
