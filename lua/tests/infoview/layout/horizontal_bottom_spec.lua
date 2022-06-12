---@brief [[
--- Tests for a portrait layout with the infoview on bottom.
---@brief ]]

require('tests.helpers')
local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

-- Emulate a 24x80 portrait display.
vim.o.columns = 24
vim.o.lines = 80

require('lean').setup{ infoview = { horizontal_position = 'bottom' } }

describe('infoview window', function()

  assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
  local lean_window = vim.api.nvim_get_current_win()

  it('is on bottom with the cursor in the Lean window', function(_)
    vim.cmd('edit! ' .. fixtures.lean_project.some_existing_file)

    assert.are.same({
      'col', {  -- see :h winlayout
        { 'leaf', lean_window },
        { 'leaf', infoview.get_current_infoview().window },
      },
    }, vim.fn.winlayout())
    assert.is.equal(lean_window, vim.api.nvim_get_current_win())
  end)
end)
