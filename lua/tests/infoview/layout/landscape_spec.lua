---@brief [[
--- Tests for infoview layout on a landscape display.
---@brief ]]

require('tests.helpers')
local infoview = require('lean.infoview')

-- Emulate a 80x24 landscape display.
vim.o.columns = 80
vim.o.lines = 24

require('lean').setup{ infoview = { autoopen = false } }

describe('infoview window', function()
  it('opens on the right with the cursor in the Lean window', function(_)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    local lean_window = vim.api.nvim_get_current_win()

    infoview.open()

    assert.are.same({
      'row', {  -- see :h winlayout
        { 'leaf', lean_window },
        { 'leaf', infoview.get_current_infoview().window },
      },
    }, vim.fn.winlayout())
    assert.is.equal(lean_window, vim.api.nvim_get_current_win())

    infoview.close()
  end)

  it('opens on the right of stacked splits at full height', function(_)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    local top_window = vim.api.nvim_get_current_win()
    vim.cmd[[botright split]]
    local bottom_window = vim.api.nvim_get_current_win()

    assert.are.same({  -- see :h winlayout
      'col', {
        { 'leaf', top_window },
        { 'leaf', bottom_window },
      },
    }, vim.fn.winlayout())

    infoview.open()

    assert.are.same({
      'row',  { -- see :h winlayout
          { 'col', { { 'leaf', top_window }, { 'leaf', bottom_window } } } ,
          { 'leaf', infoview.get_current_infoview().window },
      },
    }, vim.fn.winlayout())
  end)
end)
