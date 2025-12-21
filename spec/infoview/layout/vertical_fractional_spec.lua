---@brief [[
--- Tests for infoview vertical layout with fractional width.
---@brief ]]

local infoview = require 'lean.infoview'

-- Emulate a 80x24 portrait display.
vim.o.columns = 80
vim.o.lines = 24

require('lean').setup {
  infoview = {
    autoopen = false,
    orientation = 'vertical',
    width = 1 / 2,
  },
}

describe('infoview window fractional vertical', function()
  it('opens with fractional width', function()
    infoview.open()
    local width = infoview.get_current_infoview().window:width()
    assert.is.equal(80 / 2, width)
  end)
end)
