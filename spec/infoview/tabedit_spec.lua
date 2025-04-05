---@brief [[
--- Tests for the first Lean window being opened via `:tabedit` rather than on
--- editor startup.
---@brief ]]

local helpers = require 'spec.helpers'

require('lean').setup {}

describe('tabedit a lean file', function()
  it('does not error when opening a Lean tab from a non-Lean window', function()
    vim.cmd.tabedit 'openedViaTabedit.lean'
    helpers.insert '#check 37'
    assert.infoview_contents.are [[
      ▼ expected type (1:8-1:10)
      ⊢ Nat

      ▼ 1:1-1:7: information:
      37 : Nat
    ]]
    vim.cmd.tabclose()
  end)
end)
