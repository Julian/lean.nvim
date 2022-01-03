local helpers = require('tests.helpers')

require('lean').setup {
  lsp = { enable = true },
  lsp3 = { enable = true },
}

describe('diagnostics', function()
  it('lean 3', helpers.clean_buffer('lean3',
    [[ example : false := by trivial ]],
  function()
    helpers.wait_for_line_diagnostics()
    local diags = vim.lsp.diagnostic.get_line_diagnostics(0)
    assert.are_equal(1, #diags)
    assert.are_equal(1, diags[1].severity)
    assert(diags[1].message:match("tactic .*failed"))
  end))

  it('lean 4', helpers.clean_buffer('lean',
    [[ example : False := by trivial ]],
  function()
    helpers.wait_for_line_diagnostics()
    local diags = vim.lsp.diagnostic.get_line_diagnostics(0)
    assert.are_equal(1, #diags)
    assert.are_equal(1, diags[1].severity)
    assert(diags[1].message:match("tactic .*failed"))
  end))
end)
