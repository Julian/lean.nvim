local helpers = require('tests.helpers')
local lean_lsp_diagnostics = require('lean._util').lean_lsp_diagnostics

require('lean').setup {
  lsp = { enable = true },
  lsp3 = { enable = true },
}

describe('diagnostics', function()
  it('lean 3', helpers.clean_buffer('lean3',
    [[ example : false := by trivial ]],
  function()
    helpers.wait_for_line_diagnostics()
    local diags = lean_lsp_diagnostics()
    assert.are_equal(1, #diags)
    assert.are_equal(vim.diagnostic.severity.ERROR, diags[1].severity)
    assert(diags[1].message:match("tactic .*failed"))
  end))

  it('lean 4', helpers.clean_buffer('lean',
    [[ example : False := by trivial ]],
  function()
    helpers.wait_for_line_diagnostics()
    local diags = lean_lsp_diagnostics()
    assert.are_equal(1, #diags)
    assert.are_equal(vim.diagnostic.severity.ERROR, diags[1].severity)
    assert(diags[1].message:match("tactic .*failed"))
  end))
end)
