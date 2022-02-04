---@brief [[
--- Tests for basic Lean language support.
---@brief ]]

local helpers = require('tests.helpers')

require('lean').setup{}

describe('commenting', function()
  it('comments out single lines', helpers.clean_buffer('lean', 'def best := 37', function()
    vim.cmd('TComment')
    assert.is.same(
      '/- def best := 37 -/',
      vim.api.nvim_get_current_line()
    )
  end))

  it('comments out single lines in lean 3', helpers.clean_buffer('lean3', 'def best := 37', function()
    vim.cmd('TComment')
    assert.is.same(
      '/- def best := 37 -/',
      vim.api.nvim_get_current_line()
    )
  end))
end)
