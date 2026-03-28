local helpers = require 'spec.helpers'
local clean_buffer = helpers.clean_buffer
local sign_text_at = helpers.sign_text_at

require('lean').setup {}

-- Simulate a user who has configured custom diagnostic sign text via the
-- standard Neovim API. lean.nvim replaces vim.diagnostic's sign rendering,
-- but should still respect whatever the user has configured here.
vim.diagnostic.config {
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = '🚨',
      [vim.diagnostic.severity.WARN] = '⚠',
      [vim.diagnostic.severity.INFO] = 'ℹ',
      [vim.diagnostic.severity.HINT] = '💡',
    },
  },
}

describe('diagnostic signs with custom sign text', function()
  it(
    'respects user-configured sign text from vim.diagnostic.config',
    clean_buffer('#check (1 : String)', function()
      helpers.wait_for_line_diagnostics()
      assert.are.equal('🚨', sign_text_at(0))
    end)
  )
end)
