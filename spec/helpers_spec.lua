---@brief [[
--- Tests for our own testing helpers.
---@brief ]]

local Window = require 'std.nvim.window'
local helpers = require 'spec.helpers'

describe('clean_buffer <-> assert.contents', function()
  it(
    'creates single line buffers',
    helpers.clean_buffer('foo bar', function()
      assert.are.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), { 'foo bar' })
      assert.contents.are 'foo bar'
    end)
  )

  it(
    'creates multiline buffers',
    helpers.clean_buffer(
      [[
        foo
        bar
      ]],
      function()
        assert.are.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), { 'foo', 'bar' })
        assert.contents.are [[
          foo
          bar
        ]]
      end
    )
  )

  it(
    'creates multiline buffers with different indentation',
    helpers.clean_buffer(
      [[
        foo
          bar
          baz
      ]],
      function()
        assert.are.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), { 'foo', '  bar', '  baz' })
        assert.contents.are [[
          foo
            bar
            baz
        ]]
      end
    )
  )

  it(
    'detects actual intended trailing newlines',
    helpers.clean_buffer('foo\n\n', function()
      assert.are.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), { 'foo', '' })
      assert.contents.are 'foo\n'
    end)
  )
end)

describe(
  'assert.current_cursor',
  helpers.clean_buffer(
    [[
      foo
      bar
      baz
    ]],
    function()
      it('passes at the current cursor', function()
        local window = Window:current()
        window:set_cursor { 1, 0 }
        assert.current_cursor.is { 1, 0 }

        window:set_cursor { 2, 2 }
        assert.current_cursor.is { 2, 2 }
      end)

      it('optionally checks other windows', function()
        local first = Window:current()
        assert.current_cursor.is { 2, 2 }

        vim.cmd.split()
        local split = Window:current()
        split:set_cursor { 1, 1 }

        assert.current_cursor.is { 1, 1 }
        assert.current_cursor.is { 2, 2, window = first }

        split:close()
      end)

      it('defaults column to 0', function()
        Window:current():set_cursor { 1, 0 }
        assert.current_cursor.is { 1 }
      end)

      it('can assert just against the column', function()
        local current = Window:current()
        current:set_cursor { 1, 0 }
        assert.current_cursor { column = 0 }

        current:set_cursor { 2, 2 }
        assert.current_cursor { column = 2 }
      end)
    end
  )
)
