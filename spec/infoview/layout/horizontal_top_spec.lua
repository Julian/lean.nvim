---@brief [[
--- Tests for a portrait layout with the infoview on top.
---@brief ]]

require 'spec.helpers'
local fixtures = require 'spec.fixtures'
local infoview = require 'lean.infoview'

-- Emulate a 24x80 portrait display.
vim.o.columns = 24
vim.o.lines = 80

require('lean').setup { infoview = { horizontal_position = 'top' } }

describe('infoview window', function()
  assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
  local lean_window = vim.api.nvim_get_current_win()

  it('is on top with the cursor in the Lean window', function()
    vim.cmd('edit! ' .. fixtures.project.some_existing_file)

    assert.are.same({
      'col',
      { -- see :h winlayout
        { 'leaf', infoview.get_current_infoview().window },
        { 'leaf', lean_window },
      },
    }, vim.fn.winlayout())
    assert.current_window.is(lean_window)
  end)

  it('puts the infoview on top after repositioning', function()
    assert.are.same({
      'col',
      { -- see :h winlayout
        { 'leaf', infoview.get_current_infoview().window },
        { 'leaf', lean_window },
      },
    }, vim.fn.winlayout())
    vim.cmd.wincmd 'L'

    infoview.reposition()

    assert.are.same({
      'col',
      { -- see :h winlayout
        { 'leaf', infoview.get_current_infoview().window },
        { 'leaf', lean_window },
      },
    }, vim.fn.winlayout())
    assert.current_window.is(lean_window)
  end)
end)
