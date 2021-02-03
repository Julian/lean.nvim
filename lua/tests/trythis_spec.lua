local insert = require('tests.helpers').insert

describe('trythis', function()
  vim.api.nvim_exec('file testing123.lean', false)
  vim.fn.nvim_buf_set_option(0, 'filetype', 'lean')

  it('replaces a single try this', function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {}) -- FIXME: setup

    vim.wait(5000, vim.lsp.buf.server_ready)

    insert [[
meta def whatshouldIdo := (do tactic.trace "Try this: existsi 2; refl")
example : ∃ n, n = 2 := by whatshouldIdo]]

    vim.wait(5000, function()
      return not vim.tbl_isempty(vim.lsp.diagnostic.get_line_diagnostics())
    end)

    require('lean.trythis').swap()
    assert.is.equal(
      'example : ∃ n, n = 2 := by existsi 2; refl',
      vim.fn.nvim_get_current_line()
    )
  end)
end)
