local helpers = require('tests.helpers')
local clean_buffer = helpers.clean_buffer

describe('trythis', function()
  it('replaces a single try this', clean_buffer([[
meta def whatshouldIdo := (do tactic.trace "Try this: existsi 2; refl")
example : ∃ n, n = 2 := by whatshouldIdo]], function()
    vim.api.nvim_command('normal G$')
    helpers.wait_for_line_diagnostics()

    require('lean.trythis').swap()
    assert.is.same(
      'example : ∃ n, n = 2 := by existsi 2; refl',
      vim.fn.nvim_get_current_line()
    )
  end))
end)
