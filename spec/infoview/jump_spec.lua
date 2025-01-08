---@brief [[
--- Tests for jumping from Lean file to infoview and back
---@brief ]]

local fixtures = require 'spec.fixtures'
local infoview = require 'lean.infoview'
local helpers = require 'spec.helpers'

require('lean').setup {}

describe('infoview jumping', function()
  local lean_window

  it('jumps from Lean file to infoview', function()
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    lean_window = vim.api.nvim_get_current_win()

    vim.cmd('edit! ' .. fixtures.project.some_existing_file)
    local current_infoview = infoview.get_current_infoview()

    current_infoview:open()
    -- Both Lean and infoview windows exist
    assert.windows.are(lean_window, current_infoview.window)

    vim.cmd('LeanGotoInfoview')
    assert.current_window.is(current_infoview.window)
  end)

  it('jumps back from infoview to the associated Lean file', function()
    helpers.feed('<LocalLeader><Tab>')
    assert.current_window.is(lean_window)
  end)
end)
