---@brief [[
--- Tests for LSP-based editing extensions.
---@brief ]]

local fixtures = require 'spec.fixtures'
local helpers = require 'spec.helpers'

require('lean').setup {}

describe(']m / [m', function()
  vim.cmd.edit(fixtures.project.child 'Test/Motions.lean')

  it('moves to the end of the declaration', function()
    helpers.move_cursor { to = { 5, 4 } }
    assert.current_line.is '  have : 2 = 2 := rfl'

    vim.cmd.normal ']m'
    require('lean.edit').declaration.goto_end()

    assert.current_cursor.is { 8, 3 }
  end)
end)
