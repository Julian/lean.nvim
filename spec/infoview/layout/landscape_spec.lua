---@brief [[
--- Tests for infoview layout on a landscape display.
---@brief ]]

local Tab = require 'std.nvim.tab'
local Window = require 'std.nvim.window'

require 'spec.helpers'
local infoview = require 'lean.infoview'

-- Emulate a 80x24 landscape display.
vim.o.columns = 80
vim.o.lines = 24

require('lean').setup { infoview = { autoopen = false } }

describe('infoview window', function()
  it('opens on the right with the cursor in the Lean window', function()
    assert.is.equal(1, #Tab:current():windows())
    local lean_window = Window:current()

    infoview.open()

    assert.are.same({
      'row',
      { -- see :h winlayout
        { 'leaf', lean_window.id },
        { 'leaf', infoview.get_current_infoview().window.id },
      },
    }, vim.fn.winlayout())
    assert.current_window.is(lean_window)

    infoview.close()
  end)

  it('opens on the right of stacked splits at full height', function()
    assert.is.equal(1, #Tab:current():windows())
    local top_window = Window:current()
    vim.cmd 'botright split'
    local bottom_window = Window:current()

    assert.are.same({ -- see :h winlayout
      'col',
      {
        { 'leaf', top_window.id },
        { 'leaf', bottom_window.id },
      },
    }, vim.fn.winlayout())

    infoview.open()

    assert.are.same({
      'row',
      { -- see :h winlayout
        { 'col', { { 'leaf', top_window.id }, { 'leaf', bottom_window.id } } },
        { 'leaf', infoview.get_current_infoview().window.id },
      },
    }, vim.fn.winlayout())
  end)
end)
