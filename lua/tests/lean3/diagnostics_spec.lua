local clean_buffer = require('tests.lean3.helpers').clean_buffer
local helpers = require 'tests.helpers'
local lean_lsp_diagnostics = require('lean._util').lean_lsp_diagnostics

require('lean').setup { lsp3 = { enable = true } }

helpers.if_has_lean3('diagnostics', function()
  it(
    'are retrieved from the server',
    clean_buffer('example : false := by trivial', function()
      helpers.wait_for_line_diagnostics()
      local diags = lean_lsp_diagnostics()
      assert.are.equal(1, #diags)
      assert.are.equal(vim.diagnostic.severity.ERROR, diags[1].severity)
      assert(diags[1].message:match 'tactic .*failed')
    end)
  )
end)
