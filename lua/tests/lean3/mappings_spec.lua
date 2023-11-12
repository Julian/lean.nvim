local lean = require 'lean'
local if_has_lean3 = require('tests.helpers').if_has_lean3
local clean_buffer = require('tests.lean3.helpers').clean_buffer

lean.setup {}

if_has_lean3('mappings', function()
  it(
    'are bound the current buffer and not others',
    clean_buffer(function()
      lean.use_suggested_mappings(true)
      assert.is.same(lean.mappings.n['<LocalLeader>i'], vim.fn.maparg('<LocalLeader>i', 'n'))

      vim.cmd.new()
      assert.is.empty(vim.fn.maparg('<LocalLeader>i', 'n'))
      vim.cmd.bwipeout()
    end)
  )
end)
