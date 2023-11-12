---@brief [[
--- Tests for our own testing helpers.
---@brief ]]

local helpers = require 'tests.helpers'

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
    'detects actual intended trailing newlines',
    helpers.clean_buffer('foo\n\n', function()
      assert.are.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), { 'foo', '' })
      assert.contents.are 'foo\n'
    end)
  )
end)
