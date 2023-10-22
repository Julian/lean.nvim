local helpers = require('tests.helpers')

require('lean').setup {}

describe('trythis', function()
  it('replaces a single try this', helpers.clean_buffer([[
macro "whatshouldIdo?" : tactic => `(tactic| trace "Try this: rfl")
example : 2 = 2 := by whatshouldIdo?]], function()
    vim.cmd.normal('G$')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.current_line.is('example : 2 = 2 := by rfl')
  end))
end)
