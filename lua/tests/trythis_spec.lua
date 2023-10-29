local helpers = require('tests.helpers')
local clean_buffer = helpers.clean_buffer

require('lean').setup {}

describe('trythis', function()
  it('replaces a single try this', helpers.clean_buffer([[
    macro "whatshouldIdo?" : tactic => `(tactic| trace "Try this: rfl")
    example : 2 = 2 := by whatshouldIdo?
  ]], function()
    vim.cmd.normal('G$')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.current_line.is('example : 2 = 2 := by rfl')
  end))


  it('replaces a single try this from by', clean_buffer([[
    macro "whatshouldIdo?" : tactic => `(tactic| trace "Try this: rfl")
    example : 2 = 2 := by whatshouldIdo?
  ]], function()
    vim.cmd.normal('G$bb')
    assert.current_word.is('by')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.current_line.is('example : 2 = 2 := by rfl')
  end))

  it('replaces a single try this from earlier in the line', clean_buffer([[
    macro "whatshouldIdo?" : tactic => `(tactic| trace "Try this: rfl")
    example : 2 = 2 := by whatshouldIdo?
  ]], function()
    vim.cmd.normal('G0')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.current_line.is('example : 2 = 2 := by rfl')
  end))

  it('replaces a try this with even more unicode', clean_buffer([[
    macro "whatshouldIdo?" : tactic => `(tactic| trace "Try this: exists 0 <;> intro m <;> rfl")
    example : ∃ n : Nat, ∀ m : Nat, m = m := by whatshouldIdo?
  ]], function()
    vim.cmd.normal('G$')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.current_line.is('example : ∃ n : Nat, ∀ m : Nat, m = m := by exists 0 <;> intro m <;> rfl')
  end))
end)
