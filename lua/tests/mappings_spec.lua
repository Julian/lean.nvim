local lean = require('lean')
local clean_buffer = require('tests.helpers').clean_buffer

require('lean').setup{}

for _, ft in pairs({"lean3", "lean"}) do
describe(ft .. ' mappings', function()
  it('binds mappings in the current buffer and not others', clean_buffer(ft, '',
  function()
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
end
