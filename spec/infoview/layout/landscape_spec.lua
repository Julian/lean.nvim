---@brief [[
--- Tests for infoview layout on a landscape display.
---@brief ]]

local Window = require 'std.nvim.window'

require 'spec.helpers'
local infoview = require 'lean.infoview'

-- Emulate a 80x24 landscape display.
vim.o.columns = 80
vim.o.lines = 24

require('lean').setup { infoview = { autoopen = false } }

describe('infoview window', function()
  it('opens on the right with the cursor in the Lean window', function()
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    local lean_window = Window:current()

    infoview.open()

    assert.are.same({
      'row',
      { -- see :h winlayout
        { 'leaf', lean_window.id },
        { 'leaf', infoview.get_current_infoview().window },
      },
    }, vim.fn.winlayout())
    assert.current_window.is(lean_window)

    infoview.close()
  end)

  it('opens on the right of stacked splits at full height', function()
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    local top_window = vim.api.nvim_get_current_win()
    vim.cmd 'botright split'
    local bottom_window = vim.api.nvim_get_current_win()

    assert.are.same({ -- see :h winlayout
      'col',
      {
        { 'leaf', top_window },
        { 'leaf', bottom_window },
      },
    }, vim.fn.winlayout())

    infoview.open()

    assert.are.same({
      'row',
      { -- see :h winlayout
        { 'col', { { 'leaf', top_window }, { 'leaf', bottom_window } } },
        { 'leaf', infoview.get_current_infoview().window },
      },
    }, vim.fn.winlayout())
  end)
end)
