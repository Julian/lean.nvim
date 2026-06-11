local lean = require 'lean'
local clean_buffer = require('spec.helpers').clean_buffer

-- These tests do not exercise the infoview, so avoid (automatically)
-- opening ones, reducing load.
vim.g.lean_config =
  vim.tbl_deep_extend('force', vim.g.lean_config, { infoview = { autoopen = false } })

describe('mappings', function()
  it(
    'are bound in the current buffer and not others',
    clean_buffer(function()
      lean.use_suggested_mappings()
      assert.is.same('<Plug>(LeanInfoviewToggle)', vim.fn.maparg('<LocalLeader>i', 'n'))

      vim.cmd.new()
      assert.is.empty(vim.fn.maparg('<LocalLeader>i', 'n'))
      vim.cmd.bwipeout()
    end)
  )
end)
