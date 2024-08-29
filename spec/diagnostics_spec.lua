local helpers = require 'spec.helpers'
local lean_lsp_diagnostics = require('lean._util').lean_lsp_diagnostics

require('lean').setup { lsp = { enable = true } }

describe('diagnostics', function()
  it(
    'are retrieved from the server',
    helpers.clean_buffer('example : False := by trivial', function()
      helpers.wait_for_line_diagnostics()
      local diags = lean_lsp_diagnostics()
      assert.are.equal(1, #diags)
      assert.are.equal(vim.diagnostic.severity.ERROR, diags[1].severity)
      assert(diags[1].message:match 'tactic .*failed')
    end)
  )
end)
