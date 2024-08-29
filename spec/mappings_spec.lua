local lean = require 'lean'
local clean_buffer = require('spec.helpers').clean_buffer

lean.setup { mappings = true }

describe('mappings', function()
  it(
    'are bound in lean buffers and not others',
    clean_buffer(function()
      assert.is.same(lean.mappings.n['<LocalLeader>i'], vim.fn.maparg('<LocalLeader>i', 'n'))

      vim.cmd.new()
      assert.is.empty(vim.fn.maparg('<LocalLeader>i', 'n'))
      vim.cmd.bwipeout()
    end)
  )
end)
