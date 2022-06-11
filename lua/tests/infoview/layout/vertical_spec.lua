---@brief [[
--- Tests for a landscape layout with the infoview on the right.
---@brief ]]

require('tests.helpers')
local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

-- Emulate a 24x80 portrait display.
vim.o.columns = 80
vim.o.lines = 24

require('lean').setup{}

describe('infoview window', function()

  assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
  local lean_window = vim.api.nvim_get_current_win()

  it('is on the right with the cursor in the Lean window', function(_)
    vim.cmd('edit! ' .. fixtures.lean_project.some_existing_file)

    assert.are.same(vim.fn.winlayout(), {  -- see :h winlayout
      'row', {
        { 'leaf', lean_window },
        { 'leaf', infoview.get_current_infoview().window },
      },
    })
    assert.is.equal(vim.api.nvim_get_current_win(), lean_window)
  end)
end)
