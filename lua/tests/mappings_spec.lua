local lean = require 'lean'
local clean_buffer = require('tests.helpers').clean_buffer

require('lean').setup {}

describe('mappings', function()
  it(
    'are bound in the current buffer and not others',
    clean_buffer(function()
      lean.use_suggested_mappings(true)
      assert.is.same(lean.mappings.n['<LocalLeader>i'], vim.fn.maparg('<LocalLeader>i', 'n'))

      vim.cmd.new()
      assert.is.empty(vim.fn.maparg('<LocalLeader>i', 'n'))
      vim.cmd.bwipeout()
    end)
  )
end)
