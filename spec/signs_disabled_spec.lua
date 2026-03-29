local helpers = require 'spec.helpers'
local clean_buffer = helpers.clean_buffer

require('lean').setup { signs = { enabled = false } }

describe('diagnostic signs when disabled', function()
  it(
    'does not place custom signs',
    clean_buffer('#check (1 : String)', function()
      helpers.wait_for_line_diagnostics()
      assert.are.equal(0, #helpers.get_diagnostic_signs())
    end)
  )

  it(
    'still provides diagnostics via vim.diagnostic',
    clean_buffer('#check (1 : String)', function()
      helpers.wait_for_line_diagnostics()
      local diags = require('lean.diagnostic').lsp_diagnostics()
      assert.is_truthy(#diags > 0)
    end)
  )

  it(
    'does not disable vim.diagnostic built-in signs',
    clean_buffer('#check (1 : String)', function()
      helpers.wait_for_line_diagnostics()
      local client = vim.lsp.get_clients({ name = 'leanls', bufnr = 0 })[1]
      assert.is_truthy(client)
      local ns = vim.lsp.diagnostic.get_namespace(client.id)
      local config = vim.diagnostic.config(nil, ns)
      assert.is_not.equal(false, config.signs)
    end)
  )
end)
