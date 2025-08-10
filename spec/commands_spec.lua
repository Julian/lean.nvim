local Window = require 'std.nvim.window'

local helpers = require 'spec.helpers'

require('lean').setup { infoview = { autoopen = false } }

describe('LeanGoal', function()
  it(
    'shows a popup with the goal',
    helpers.clean_buffer('example : 2 = 2 := by sorry', function()
      helpers.move_cursor { to = { 1, 20 } }
      helpers.wait_for_processing()

      local initial_window = Window:current()
      vim.cmd.LeanGoal()
      local popup = helpers.wait_for_new_window { initial_window }

      assert.are.same({
        '⊢ 2 = 2',
      }, popup:buffer():lines())

      popup:close()
    end)
  )
end)

describe('LeanTermGoal', function()
  it(
    'shows a popup with the term goal',
    helpers.clean_buffer('def n : Nat := 37', function()
      helpers.move_cursor { to = { 1, 16 } }
      helpers.wait_for_processing()

      local initial_window = Window:current()
      vim.cmd.LeanTermGoal()
      local popup = helpers.wait_for_new_window { initial_window }

      assert.are.same({
        '▼ expected type (1:16-1:18)',
        '⊢ Nat',
      }, popup:buffer():lines())

      popup:close()
    end)
  )
end)
