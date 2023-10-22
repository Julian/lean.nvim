local helpers = require('tests.helpers')
local clean_buffer = require('tests.lean3.helpers').clean_buffer

require('lean').setup {}

helpers.if_has_lean3('sorry', function()
  it('inserts sorries for each remaining goal', clean_buffer([[
def foo (n : nat) : n = n := begin
  induction n with d hd,
end]], function()
    vim.cmd('normal! 3gg$')
    helpers.wait_for_line_diagnostics()

    vim.cmd('normal! 2gg$')
    require('lean.sorry').fill()
    assert.contents.are[[
def foo (n : nat) : n = n := begin
  induction n with d hd,
  { sorry },
  { sorry },
end]]
  end))

  it('leaves the cursor in the first sorry', clean_buffer([[
def foo (n : nat) : n = n := begin
  induction n with d hd,
end]], function()
    vim.cmd('normal! 3gg$')
    helpers.wait_for_line_diagnostics()

    vim.cmd('normal! 2gg$')
    require('lean.sorry').fill()
    vim.cmd('normal! cefoo')
    assert.contents.are[[
def foo (n : nat) : n = n := begin
  induction n with d hd,
  { foo },
  { sorry },
end]]
  end))

  it('indents sorry blocks when needed', clean_buffer([[
def foo (n : nat) : n = n := begin
  induction n with d hd,

end]], function()
    vim.cmd('normal! 4gg$')
    helpers.wait_for_line_diagnostics()

    vim.cmd('normal! 3gg0')
    require('lean.sorry').fill()
    assert.contents.are[[
def foo (n : nat) : n = n := begin
  induction n with d hd,

  { sorry },
  { sorry },
end]]
  end))

  it('does nothing if there are no goals', clean_buffer([[
def foo (n : nat) : n = n := begin
  refl,
end]], function()
    vim.cmd('normal! 2gg$')
    require('lean.sorry').fill()
    assert.contents.are[[
def foo (n : nat) : n = n := begin
  refl,
end]]
  end))

end)
