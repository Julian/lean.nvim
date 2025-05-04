local Window = require 'std.nvim.window'

local helpers = require 'spec.helpers'

require('lean').setup {}

describe('LeanTermGoal', function()
  it(
    'shows a popup with the term goal',
    helpers.clean_buffer('def n : Nat := 37', function()
      helpers.move_cursor { to = { 1, 16 } }
      helpers.wait_for_loading_pins()

      local initial_window = Window:current()
      vim.cmd.LeanTermGoal()
      local popup = helpers.wait_for_new_window { initial_window }

      assert.are.same({
        '▼ expected type (1:16-1:18)',
        '⊢ Nat',
      }, vim.api.nvim_buf_get_lines(popup:bufnr(), 0, -1, false))
    end)
  )
end)
