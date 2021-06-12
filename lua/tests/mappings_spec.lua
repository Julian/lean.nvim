local lean = require('lean')
local clean_buffer = require('tests.helpers').clean_buffer

describe('mappings', function()
  require('tests.helpers').setup {}
  it('binds mappings in the current buffer and not others', clean_buffer('',
  function()
    lean.use_suggested_mappings(true)
    assert.is.same(
      lean.mappings.n['<LocalLeader>3'],
      vim.fn.maparg("<LocalLeader>3", 'n')
    )

    vim.cmd('new')
    assert.is.same('', vim.fn.maparg("<LocalLeader>3", 'n'))
    vim.cmd('bwipeout')
  end))
end)
