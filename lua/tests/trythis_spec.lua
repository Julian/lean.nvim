local helpers = require('tests.helpers')

require('lean').setup {}

describe('trythis', function()
  it('replaces a single try this', helpers.clean_buffer("lean3", [[
meta def whatshouldIdo := (do tactic.trace "Try this: existsi 2; refl\n")
example : ∃ n, n = 2 := by whatshouldIdo]], function()
    vim.api.nvim_command('normal G$')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.is.same(
      'example : ∃ n, n = 2 := by existsi 2; refl',
      vim.api.nvim_get_current_line()
    )
  end))

  it('replaces a single try this from by', helpers.clean_buffer("lean3", [[
meta def whatshouldIdo := (do tactic.trace "Try this: existsi 2; refl\n")
example : ∃ n, n = 2 := by whatshouldIdo]], function()
    vim.api.nvim_command('normal G$bb')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.is.same(
      'example : ∃ n, n = 2 := by existsi 2; refl',
      vim.api.nvim_get_current_line()
    )
  end))

  it('replaces a single try this from earlier in the line', helpers.clean_buffer("lean3", [[
meta def whatshouldIdo := (do tactic.trace "Try this: existsi 2; refl\n")
example : ∃ n, n = 2 := by whatshouldIdo]], function()
    vim.api.nvim_command('normal G0')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.is.same(
      'example : ∃ n, n = 2 := by existsi 2; refl',
      vim.api.nvim_get_current_line()
    )
  end))

  it('replaces a try this with even more unicode', helpers.clean_buffer("lean3", [[
meta def whatshouldIdo := (do tactic.trace "Try this: existsi 0; intro m; refl")
example : ∃ n : nat, ∀ m : nat, m = m := by whatshouldIdo]], function()
    vim.api.nvim_command('normal G$')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.is.same(
      'example : ∃ n : nat, ∀ m : nat, m = m := by existsi 0; intro m; refl',
      vim.api.nvim_get_current_line()
    )
  end))

  -- Emitted by e.g. hint
  -- luacheck: ignore
  it('replaces squashed together try this messages', helpers.clean_buffer("lean3", [[
meta def whatshouldIdo := (do tactic.trace "the following tactics solve the goal\n---\nTry this: finish\nTry this: tauto\n")
example : ∃ n, n = 2 := by whatshouldIdo]], function()
    vim.api.nvim_command('normal G$')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.is.same(
      'example : ∃ n, n = 2 := by finish',
      vim.api.nvim_get_current_line()
    )
  end))

  -- Emitted by e.g. pretty_cases
  it('replaces multiline try this messages', helpers.clean_buffer("lean3", [[
meta def whatshouldIdo := (do tactic.trace "Try this: existsi 2,\n  refl,\n")
example : ∃ n, n = 2 := by {
  whatshouldIdo
}]], function()
    vim.api.nvim_command('normal 3gg$')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.contents.are[[
meta def whatshouldIdo := (do tactic.trace "Try this: existsi 2,\n  refl,\n")
example : ∃ n, n = 2 := by {
  existsi 2,
  refl,
}]]
  end))

  -- Emitted by e.g. library_search
  it('trims by exact foo to just foo', helpers.clean_buffer("lean3", [[
meta def whatshouldIdo := (do tactic.trace "Try this: exact rfl")
example {n : nat} : n = n := by whatshouldIdo]], function()
    vim.api.nvim_command('normal G$')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.is.same(
      'example {n : nat} : n = n := rfl',
      vim.api.nvim_get_current_line()
    )
  end))

  -- Also emitted by e.g. library_search
  it('trims by exact foo to just foo', helpers.clean_buffer("lean3", [[
meta def whatshouldIdo := (do tactic.trace "Try this: exact rfl")
structure foo :=
(bar (n : nat) : n = n)
example : foo := ⟨by whatshouldIdo⟩]], function()
    vim.api.nvim_command('normal G$h')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.is.same(
      'example : foo := ⟨rfl⟩',
      vim.api.nvim_get_current_line()
    )
  end))

  -- A line containing `squeeze_simp at bar` will re-suggest `at bar`, so
  -- ensure it doesn't appear twice
  it('trims simp at foo when it will be duplicated', helpers.clean_buffer("lean3", [[
meta def whatshouldIdo := (do tactic.trace "Try this: simp [foo] at bar")
example {n : nat} : n = n := by whatshouldIdo at bar]], function()
    vim.api.nvim_command('normal G$')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.is.same(
      'example {n : nat} : n = n := by simp [foo] at bar',
      vim.api.nvim_get_current_line()
    )
  end))

  -- Handle `squeeze_simp [foo]` similarly.
  it('trims simp [foo] when it will be duplicated', helpers.clean_buffer("lean3", [[
meta def whatshouldIdo (L : list name) := (do tactic.trace "Try this: simp [foo, baz]")
example {n : nat} : n = n := by whatshouldIdo [`nat]
]], function()
    vim.api.nvim_command('normal G$k')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.is.same(
      'example {n : nat} : n = n := by simp [foo, baz]',
      vim.api.nvim_get_current_line()
    )
  end))

  -- Handle `squeeze_simp [foo] at bar` similarly.
  it('trims simp [foo] at bar when it will be duplicated', helpers.clean_buffer("lean3", [[
meta def whatshouldIdo (L : list name) := (do tactic.trace "Try this: simp [foo, baz] at bar")
example {n : nat} : n = n := by whatshouldIdo [`nat] at bar]], function()
    vim.api.nvim_command('normal G$')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.is.same(
      'example {n : nat} : n = n := by simp [foo, baz] at bar',
      vim.api.nvim_get_current_line()
    )
  end))

  it('replaces squashed suggestions from earlier in the line', helpers.clean_buffer("lean3", [[
meta def whatshouldIdo := (do tactic.trace "Try this: exact rfl")
example {n : nat} : n = n := by whatshouldIdo]], function()
    vim.api.nvim_command('normal G0')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.is.same(
      'example {n : nat} : n = n := rfl',
      vim.api.nvim_get_current_line()
    )
  end))
end)
