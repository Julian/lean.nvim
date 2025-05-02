---@brief [[
--- Tests for moving the cursor to goals.
---@brief ]]

local Window = require 'std.nvim.window'

local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe(
  'move_cursor_to_goal',
  helpers.clean_buffer(
    [[
  example {n : Nat} : n = n ∨ n = 37 ∨ n = 73 := by
    cases 37
    cases 73
    left
    rfl
  ]],
    function()
      local lean_window

      it('moves the cursor to the first goal by default', function()
        lean_window = Window:current()

        helpers.move_cursor { to = { 4, 3 } }
        local current_infoview = infoview.get_current_infoview()

        helpers.wait_for_loading_pins(current_infoview)
        assert.matches('3 goals', current_infoview:get_line(0))

        -- Move the cursor anywhere else.
        helpers.move_cursor { window = current_infoview.window, to = { 1, 0 } }

        current_infoview:move_cursor_to_goal(1)

        current_infoview:enter()
        assert.current_line.is '⊢ n = n'
        lean_window:make_current()
      end)

      it('moves the cursor to a specific goal number', function()
        local current_infoview = infoview.get_current_infoview()

        current_infoview:enter()
        assert.current_line.is '⊢ n = n'
        lean_window:make_current()

        current_infoview:move_cursor_to_goal(2)

        current_infoview:enter()
        assert.current_line.is '⊢ n = n ∨ n = 0 ∨ n = n✝ + 1'
        lean_window:make_current()
      end)
    end
  )
)
