---@brief [[
--- Tests for a portrait layout with the infoview on bottom.
---@brief ]]

local Window = require 'std.nvim.window'

require 'spec.helpers'
local fixtures = require 'spec.fixtures'
local infoview = require 'lean.infoview'

-- Emulate a 24x80 portrait display.
vim.o.columns = 24
vim.o.lines = 80

require('lean').setup { infoview = { horizontal_position = 'bottom' } }

describe('infoview window', function()
  assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
  local lean_window = Window:current()

  it('is on bottom with the cursor in the Lean window', function()
    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }

    assert.are.same({
      'col',
      { -- see :h winlayout
        { 'leaf', lean_window.id },
        { 'leaf', infoview.get_current_infoview().window },
      },
    }, vim.fn.winlayout())
    assert.current_window.is(lean_window)
  end)
end)
