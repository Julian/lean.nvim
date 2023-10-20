local lean = require('lean')
local helpers = require('tests.helpers')

require('lean').setup {}

helpers.if_has_lean3('mappings', function()
  it('are bound the current buffer and not others', helpers.clean_buffer('lean3', '', function()
    lean.use_suggested_mappings(true)
    assert.is.same(
      lean.mappings.n['<LocalLeader>i'],
      vim.fn.maparg("<LocalLeader>i", 'n')
    )

    vim.cmd('new')
    assert.is.same('', vim.fn.maparg("<LocalLeader>i", 'n'))
    vim.cmd('bwipeout')
  end))
end)
