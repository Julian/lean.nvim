local helpers = require('tests.helpers')

require('lean').setup {}

describe('trythis', function()
  it('replaces a single try this', helpers.clean_buffer('lean', [[
macro "whatshouldIdo?" : tactic => `(tactic| trace "Try this: rfl")
example : 2 = 2 := by whatshouldIdo?]], function()
    vim.api.nvim_command('normal G$')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.is.same(
      'example : 2 = 2 := by rfl',
      vim.api.nvim_get_current_line()
    )
  end))
end)
