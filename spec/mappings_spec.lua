local infoview = require 'lean.infoview'
local clean_buffer = require('spec.helpers').clean_buffer

vim.g.lean_config = { mappings = true }

describe('mappings', function()
  describe('for lean buffers', function()
    local any_lean_lhs = '<LocalLeader>i'
    local rhs = '<Cmd>LeanInfoviewToggle<CR>'

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

    it(
      'all have desc set',
      clean_buffer(function()
        local mappings = vim.api.nvim_buf_get_keymap(0, 'nivx')
        assert.message('unexpectedly empty').is_not_empty(mappings)

        local msg = 'no desc for `%s`:\n%s'
        for _, each in ipairs(mappings) do
          assert.message(msg:format(each.lhs, vim.inspect(each))).is_not.empty(each.desc)
        end
      end)
    )
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

    it(
      'all have desc set',
      clean_buffer(function()
        infoview.go_to()

        -- TODO: Also check tooltips.

        local mappings = vim.api.nvim_buf_get_keymap(0, 'nivx')
        assert.message('unexpectedly empty').is_not_empty(mappings)

        local msg = 'no desc for `%s`:\n%s'
        for _, each in ipairs(mappings) do
          assert.message(msg:format(each.lhs, vim.inspect(each))).is_not.empty(each.desc)
        end
      end)
    )

    it('are not bound in other buffers', function()
      vim.cmd.new()
      assert.is.empty(vim.fn.maparg(any_infoview_lhs, 'n', false, true))
      vim.cmd.bwipeout()
    end)
  end)
end)
