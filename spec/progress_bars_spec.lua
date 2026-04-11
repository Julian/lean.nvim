local helpers = require 'spec.helpers'

require('lean').setup {}

---Return whether there are any progress bar signs in the current buffer.
local function has_progress_bar_signs()
  local ns = vim.api.nvim_create_namespace 'lean.progress'
  local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
  return #marks > 0
end

describe('progress bars', function()
  it(
    'are cleared when the LSP server dies',
    helpers.clean_buffer('#eval IO.sleep 5000', function()
      -- Wait for progress bars to actually appear.
      local succeeded = vim.wait(30000, has_progress_bar_signs)
      assert.message('progress bar signs never appeared').is_true(succeeded)

      -- Kill the LSP while signs are visible.
      for _, client in ipairs(vim.lsp.get_clients { bufnr = 0 }) do
        client:stop()
      end
      succeeded = vim.wait(5000, function()
        return vim.tbl_isempty(vim.lsp.get_clients { bufnr = 0 })
      end)
      assert.message("Couldn't kill the LSP!").is_true(succeeded)

      assert.message('progress bar signs were not cleaned up').is_false(has_progress_bar_signs())
    end)
  )
end)
