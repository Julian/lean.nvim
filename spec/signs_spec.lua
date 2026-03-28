local helpers = require 'spec.helpers'
local clean_buffer = helpers.clean_buffer
local sign_text_at = helpers.sign_text_at

require('lean').setup {}

describe('diagnostic signs', function()
  it(
    'shows severity signs for single-line diagnostics',
    clean_buffer('#check (1 : String)', function()
      helpers.wait_for_line_diagnostics()
      assert.are.equal('E', sign_text_at(0))
    end)
  )

  it(
    'colors signs by severity',
    clean_buffer('#check (1 : String)', function()
      helpers.wait_for_line_diagnostics()
      local marks = helpers.get_diagnostic_signs()
      assert.is_truthy(#marks > 0)
      assert.are.equal('DiagnosticSignError', marks[1][4].sign_hl_group)
    end)
  )

  it(
    'shows full-range guide characters for multi-line diagnostics',
    clean_buffer(
      [[
        example : Nat :=
          (1 +
           2 +
           "hello")
      ]],
      function()
        vim.cmd.normal { '2gg', bang = true }
        helpers.wait_for_line_diagnostics()

        -- This produces a type error whose fullRange (lines 1-3) extends
        -- past the clipped range (lines 1-2). Line 0 has no diagnostic.
        assert.is_nil(sign_text_at(0))
        assert.are.equal('┌', sign_text_at(1))
        assert.are.equal('│', sign_text_at(2))
        assert.are.equal('└', sign_text_at(3))
      end
    )
  )

  it(
    'gives higher severity diagnostics higher sign priority',
    clean_buffer('#check (1 : String)', function()
      helpers.wait_for_line_diagnostics()
      local marks = helpers.get_diagnostic_signs()
      assert.is_truthy(#marks > 0)
      assert.are.equal(14, marks[1][4].priority)
    end)
  )

  it(
    'disables vim.diagnostic built-in signs for the leanls namespace',
    clean_buffer('#check (1 : String)', function()
      helpers.wait_for_line_diagnostics()
      local client = vim.lsp.get_clients({ name = 'leanls', bufnr = 0 })[1]
      assert.is_truthy(client)
      local ns = vim.lsp.diagnostic.get_namespace(client.id)
      local config = vim.diagnostic.config(nil, ns)
      assert.are.equal(false, config.signs)
    end)
  )
end)
