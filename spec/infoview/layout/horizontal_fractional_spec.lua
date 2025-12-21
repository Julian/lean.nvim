---@brief [[
--- Tests for infoview horizontal layout with fractional height.
---@brief ]]

local infoview = require 'lean.infoview'

-- Emulate a 80x24 landscape display.
vim.o.columns = 80
vim.o.lines = 24

require('lean').setup {
  infoview = {
    autoopen = false,
    orientation = 'horizontal',
    height = 0.5,
  },
}

describe('infoview window fractional horizontal', function()
  it('opens with fractional height', function()
    infoview.open()
    local height = infoview.get_current_infoview().window:height()
    assert.is.equal(24 / 2, height)
  end)
end)
