local helpers = require('tests.helpers')
local feed, insert = helpers.feed, helpers.insert

describe('translations', function()
  vim.fn.nvim_buf_set_option(0, 'filetype', 'lean')

  it('expands \\-prefixed predefined substitutions on tab', function()
    insert('\\a<Tab>')
    assert.is.equal('α', vim.fn.nvim_get_current_line())

    feed('ggdG')  -- FIXME: Start with clear buffers...
  end)

  it('does not autoexpand', function()
    insert('\\a')
    assert.is.equal('\\a', vim.fn.nvim_get_current_line())

    feed('ggdG')  -- FIXME: Start with clear buffers...
  end)

  it('expands mid-word', function()
    pending('norcalli/snippets.nvim#17')

    insert('(\\a<Tab>')
    --[[ XXX: See nvim-lua/plenary.nvim#49
    assert.is.equal('(α', vim.fn.nvim_get_current_line())
    ]]

    feed('ggdG')  -- FIXME: Start with clear buffers...
  end)
end)
