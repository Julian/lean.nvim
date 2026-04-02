local infoview = require 'lean.infoview'
local lean = require 'lean'
local clean_buffer = require('spec.helpers').clean_buffer

vim.g.lean_config = { mappings = true }

describe('mappings', function()
  describe('for lean buffers', function()
    local any_lean_lhs = '<LocalLeader>i'
    local its_plug = ('<Plug>(%s)'):format(vim.iter(lean.mappings):find(function(e)
      return e[1] == any_lean_lhs
    end)[2])

    it(
      'are bound in lean buffers',
      clean_buffer(function()
        assert.is.same(its_plug, vim.fn.maparg(any_lean_lhs, 'n'))
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

    it(
      'can restart file',
      clean_buffer(function()
        assert.is.same('<Plug>(LeanRestartFile)', vim.fn.maparg('<LocalLeader>r', 'n'))
      end)
    )
  end)

  describe('<Plug> mappings for lean buffers', function()
    it(
      'are registered buffer-locally in lean buffers',
      clean_buffer(function()
        for _, each in ipairs(lean.mappings) do
          local plug = ('<Plug>(%s)'):format(each[2])
          assert
            .message(('buffer-local <Plug> missing in lean buffer: %s'):format(plug)).is_not
            .empty(vim.fn.maparg(plug, 'n'))
        end
      end)
    )

    it(
      'all have a callback and matching desc',
      clean_buffer(function()
        for _, each in ipairs(lean.mappings) do
          local cmd, opts = each[2], each[3]
          local plug = ('<Plug>(%s)'):format(cmd)
          local mapping = vim.fn.maparg(plug, 'n', false, true)
          assert
            .message(('buffer-local <Plug> for %s has no callback'):format(plug)).is
            .same('function', type(mapping.callback))
          assert
            .message(('buffer-local <Plug> desc for %s does not match mapping desc'):format(plug)).is
            .same(opts.desc, mapping.desc)
        end
      end)
    )

    it('are not bound in other buffers', function()
      vim.cmd.new()
      for _, each in ipairs(lean.mappings) do
        local plug = ('<Plug>(%s)'):format(each[2])
        assert
          .message(('lean buffer <Plug> should not be in other buffers: %s'):format(plug)).is
          .empty(vim.fn.maparg(plug, 'n'))
      end
      vim.cmd.bwipeout()
    end)
  end)

  describe('for infoviews', function()
    local any_infoview_lhs = '<Esc>'
    local any_infoview_plug = '<Plug>(LeanInfoviewClearAll)'

    it(
      'are bound in infoviews',
      clean_buffer(function()
        infoview.go_to()
        assert.is.same(any_infoview_plug, vim.fn.maparg(any_infoview_lhs, 'n'))
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

  describe('<Plug> mappings for infoviews', function()
    it(
      'are registered as buffer-local maps in infoviews',
      clean_buffer(function()
        infoview.go_to()
        local plug_maps = vim.tbl_filter(function(m)
          return m.lhs:match '^<Plug>'
        end, vim.api.nvim_buf_get_keymap(0, 'n'))
        assert.message('no <Plug> mappings found in infoview').is_not_empty(plug_maps)
        for _, m in ipairs(plug_maps) do
          assert
            .message(('buffer-local <Plug> has no desc in infoview: %s'):format(m.lhs)).is_not
            .empty(m.desc)
        end
      end)
    )

    it(
      'are not bound in unrelated buffers',
      clean_buffer(function()
        infoview.go_to()
        local plug_maps = vim.tbl_filter(function(m)
          return m.lhs:match '^<Plug>'
        end, vim.api.nvim_buf_get_keymap(0, 'n'))
        vim.cmd.new()
        for _, m in ipairs(plug_maps) do
          assert
            .message(('infoview <Plug> should not be global: %s'):format(m.lhs)).is
            .empty(vim.fn.maparg(m.lhs, 'n'))
        end
        vim.cmd.bwipeout()
      end)
    )
  end)
end)
