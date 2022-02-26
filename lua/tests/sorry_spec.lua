local helpers = require('tests.helpers')
local clean_buffer = helpers.clean_buffer

require('lean').setup {}

describe('sorry', function()
  it('inserts sorries for each remaining goal', clean_buffer("lean3", [[
def foo (n : nat) : n = n := begin
  induction n with d hd,
end]], function()
    vim.api.nvim_command('normal! 3gg$')
    helpers.wait_for_line_diagnostics()

    vim.api.nvim_command('normal! 2gg$')
    require('lean.sorry').fill()
    assert.contents.are[[
def foo (n : nat) : n = n := begin
  induction n with d hd,
  { sorry },
  { sorry },
end]]
  end))

  it('leaves the cursor in the first sorry', clean_buffer("lean3", [[
def foo (n : nat) : n = n := begin
  induction n with d hd,
end]], function()
    vim.api.nvim_command('normal! 3gg$')
    helpers.wait_for_line_diagnostics()

    vim.api.nvim_command('normal! 2gg$')
    require('lean.sorry').fill()
    vim.api.nvim_command('normal! cefoo')
    assert.contents.are[[
def foo (n : nat) : n = n := begin
  induction n with d hd,
  { foo },
  { sorry },
end]]
  end))

  it('indents sorry blocks when needed',
    clean_buffer("lean3", [[
def foo (n : nat) : n = n := begin
  induction n with d hd,

end]], function()
    vim.api.nvim_command('normal! 4gg$')
    helpers.wait_for_line_diagnostics()

    vim.api.nvim_command('normal! 3gg0')
    require('lean.sorry').fill()
    assert.contents.are[[
def foo (n : nat) : n = n := begin
  induction n with d hd,

  { sorry },
  { sorry },
end]]
  end))

  it('does nothing if there are no goals', clean_buffer("lean3", [[
def foo (n : nat) : n = n := begin
  refl,
end]], function()
    vim.api.nvim_command('normal! 2gg$')
    require('lean.sorry').fill()
    assert.contents.are[[
def foo (n : nat) : n = n := begin
  refl,
end]]
  end))
end)
