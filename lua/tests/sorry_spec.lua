local helpers = require('tests.helpers')
local clean_buffer = helpers.clean_buffer

require('lean').setup {}

describe('sorry', function()
  it('lean3 inserts sorries for each remaining goal', clean_buffer("lean3", [[
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

  it('lean inserts sorries for each of multiple remaining goals', clean_buffer('lean', [[
example (p q : Prop) : p ∧ q ↔ q ∧ p := by
  constructor]],
  function()
    helpers.wait_for_line_diagnostics()

    vim.api.nvim_command('normal! 2gg$')
    require('lean.sorry').fill()
    assert.contents.are[[
example (p q : Prop) : p ∧ q ↔ q ∧ p := by
  constructor
  · sorry
  · sorry]]
  end))

  it('lean inserts a sorry for the remaining goal', clean_buffer('lean', [[
example (p : Prop) : p → p := by]],
  function()
    helpers.wait_for_line_diagnostics()

    vim.api.nvim_command('normal! gg$')
    require('lean.sorry').fill()
    assert.contents.are[[
example (p : Prop) : p → p := by
sorry]]
  end))

  it('lean3 leaves the cursor in the first sorry', clean_buffer("lean3", [[
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

  it('lean leaves the cursor in the first sorry', clean_buffer("lean", [[
def foo (p q : Prop) : p ∧ q ↔ q ∧ p := by
  constructor]], function()
    helpers.wait_for_line_diagnostics()

    vim.api.nvim_command('normal! 2gg$')
    require('lean.sorry').fill()
    vim.api.nvim_command('normal! cebar')
    assert.contents.are[[
def foo (p q : Prop) : p ∧ q ↔ q ∧ p := by
  constructor
  · bar
  · sorry]]
  end))

  it('lean leaves the cursor in the only sorry', clean_buffer("lean", [[
def foo (p q : Prop) : p ∧ q →  q ∧ p := by
  intro h]], function()
    helpers.wait_for_line_diagnostics()

    vim.api.nvim_command('normal! 2gg$')
    require('lean.sorry').fill()
    vim.api.nvim_command('normal! cebar')
    assert.contents.are[[
def foo (p q : Prop) : p ∧ q →  q ∧ p := by
  intro h
  bar]]
  end))

  it('lean3 indents sorry blocks when needed',
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

  it('lean indents sorry blocks when needed',
    clean_buffer("lean", [[
def foo (p q : Prop) : p ∧ q ↔ q ∧ p := by
  constructor

]], function()
    vim.api.nvim_command('normal! gg$')
    helpers.wait_for_line_diagnostics()

    vim.api.nvim_command('normal! 3gg0')
    require('lean.sorry').fill()
    assert.contents.are[[
def foo (p q : Prop) : p ∧ q ↔ q ∧ p := by
  constructor

  · sorry
  · sorry
]]
  end))

  it('lean single goal within multiple goal block',
    clean_buffer("lean", [[
def foo (p q : Prop) : p ∧ q ↔ q ∧ p := by
  constructor
  · intro h
  · sorry
]], function()
    vim.api.nvim_command('normal! 3gg$')
    helpers.wait_for_line_diagnostics()

    require('lean.sorry').fill()
    assert.contents.are[[
def foo (p q : Prop) : p ∧ q ↔ q ∧ p := by
  constructor
  · intro h
    sorry
  · sorry
]]
  end))

  it('lean3 does nothing if there are no goals', clean_buffer("lean3", [[
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


  it('lean does nothing if there are no goals', clean_buffer("lean", [[
def foo (n : Nat) : n = n := by
  rfl]], function()
    vim.api.nvim_command('normal! 2gg$')
    require('lean.sorry').fill()
    assert.contents.are[[
def foo (n : Nat) : n = n := by
  rfl]]
  end))
end)
