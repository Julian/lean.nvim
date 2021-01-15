local helpers = require('tests.helpers')
local feed, insert = helpers.feed, helpers.insert

describe('translations', function()
  it('expands \\-prefixed predefined substitutions on tab', function()
    vim.fn.nvim_buf_set_option(0, 'filetype', 'lean')

    insert('\\a<Tab>')
    assert.is.equal('α', vim.fn.nvim_get_current_line())

    feed('dd')  -- FIXME: Start with clear buffers...
  end)

  it('does not autoexpand', function()
    insert('\\a')
    assert.is.equal('\\a', vim.fn.nvim_get_current_line())

    feed('dd')  -- FIXME: Start with clear buffers...
  end)
end)
