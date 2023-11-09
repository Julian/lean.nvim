---@brief [[
--- Tests for matchit support.
---@brief ]]

local helpers = require('tests.helpers')

require('lean').setup{}

describe('matchit', function()
  it('jumps between section start and end', helpers.clean_buffer([[
    section foo

    def f := 37

    end foo
  ]], function()
    vim.cmd.normal('gg')
    assert.current_line.is('section foo')
    vim.cmd.normal('%')
    assert.current_line.is('end foo')
  end))

  it('jumps between anonymous sections', helpers.clean_buffer([[
    section

    def f := 37

    end
  ]], function()
    vim.cmd.normal('gg')
    assert.current_line.is('section')
    vim.cmd.normal('%')
    assert.current_line.is('end')
  end))

  it('jumps between namespace start and end', helpers.clean_buffer([[
    namespace foo

    section bar

    def f := 37

    end bar

    end foo
  ]], function()
    vim.cmd.normal('gg')
    assert.current_line.is('namespace foo')
    vim.cmd.normal('%')
    assert.current_line.is('end foo')
  end))
end)
