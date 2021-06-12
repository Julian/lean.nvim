local helpers = require('tests.helpers')
local clean_buffer = helpers.clean_buffer

describe('sorry', function()
  helpers.setup { lsp3 = { enable = true } }
  it('inserts sorries for each remaining goal', clean_buffer([[
def foo (n : nat) : n = n := begin
  induction n with d hd,
end]], function()
    vim.api.nvim_command('normal! 3gg$')
    helpers.wait_for_line_diagnostics()

    vim.api.nvim_command('normal! 2gg$')
    require('lean.sorry').fill()
    assert.is.same(
      [[
def foo (n : nat) : n = n := begin
  induction n with d hd,
  { sorry },
  { sorry },
end]], table.concat(vim.fn.getline(1, '$'), '\n'))
  end))

  it('does nothing if there are no goals', clean_buffer([[
def foo (n : nat) : n = n := begin
  refl,
end]], function()
    vim.api.nvim_command('normal! 2gg$')
    require('lean.sorry').fill()
    assert.is.same(
      [[
def foo (n : nat) : n = n := begin
  refl,
end]], table.concat(vim.fn.getline(1, '$'), '\n'))
  end))
end)
