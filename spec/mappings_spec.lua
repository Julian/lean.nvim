local infoview = require 'lean.infoview'
local lean = require 'lean'
local clean_buffer = require('spec.helpers').clean_buffer

vim.g.lean_config = { mappings = true }

describe('mappings', function()
  describe('for lean buffers', function()
    local any_lean_lhs = '<LocalLeader>i'
    local rhs = lean.mappings.n[any_lean_lhs]

    it(
      'are bound in lean buffers',
      clean_buffer(function()
        assert.is.not_nil(rhs)
        assert.is.same(rhs, vim.fn.maparg(any_lean_lhs, 'n'))
      end)
    )

    it('are not bound in other buffers', function()
      vim.cmd.new()
      assert.is.empty(vim.fn.maparg(any_lean_lhs, 'n'))
      vim.cmd.bwipeout()
    end)
  end)

  describe('for infoviews', function()
    local any_infoview_lhs = '<Esc>'

    it(
      'are bound in infoviews',
      clean_buffer(function()
        infoview.go_to()
        local mapping = vim.fn.maparg(any_infoview_lhs, 'n', false, true)
        assert.is.same('function', type(mapping.callback))
      end)
    )

    it('are not bound in other buffers', function()
      vim.cmd.new()
      assert.is.empty(vim.fn.maparg(any_infoview_lhs, 'n', false, true))
      vim.cmd.bwipeout()
    end)
  end)
end)
