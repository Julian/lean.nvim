local insert = require('tests.helpers').insert

describe('sorry', function()
  vim.api.nvim_exec('file testing123.lean', false)
  vim.fn.nvim_buf_set_option(0, 'filetype', 'lean')

  it('inserts sorries for each remaining goal', function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {}) -- FIXME: setup

    vim.wait(5000, vim.lsp.buf.server_ready)

    insert [[
def foo (n : nat) : n = n := begin
  induction n with d hd,
end]]

    vim.wait(5000, function()
      return not vim.tbl_isempty(vim.lsp.diagnostic.get_line_diagnostics())
    end)

    vim.api.nvim_exec(':normal! 2gg$', false)
    require('lean.sorry').fill()
    assert.is.same(
      [[
def foo (n : nat) : n = n := begin
  induction n with d hd,
  { sorry },
  { sorry },
  end]], table.concat(vim.fn.getline(1, '$'), '\n'))
  end)
end)
