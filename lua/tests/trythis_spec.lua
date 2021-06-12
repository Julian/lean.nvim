local helpers = require('tests.helpers')

describe('trythis', function()
  helpers.setup { lsp3 = { enable = true } }
  it('replaces a single try this', helpers.clean_buffer([[
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

  -- Emitted by e.g. pretty_cases
  it('replaces multiline try this messages', helpers.clean_buffer([[
meta def whatshouldIdo := (do tactic.trace "Try this: existsi 2,\nrefl,\n")
example : ∃ n, n = 2 := by {
  whatshouldIdo
}]], function()
    vim.api.nvim_command('normal 3gg$')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.contents.are([[
meta def whatshouldIdo := (do tactic.trace "Try this: existsi 2,\nrefl,\n")
example : ∃ n, n = 2 := by {
  existsi 2,
  refl,
}]])
  end))

  -- Emitted by e.g. hint
  -- luacheck: ignore
  it('replaces squashed together try this messages', helpers.clean_buffer([[
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
end)
