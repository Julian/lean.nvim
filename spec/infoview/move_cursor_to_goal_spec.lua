---@brief [[
--- Tests for moving the cursor to goals.
---@brief ]]

local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup { infoview = { use_widgets = false } }

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
        lean_window = vim.api.nvim_get_current_win()

        helpers.move_cursor { to = { 4, 2 } }
        local current_infoview = infoview.get_current_infoview()

        helpers.wait_for_loading_pins(current_infoview)
        assert.matches('3 goals', current_infoview:get_line(0))

        -- Move the cursor anywhere else.
        helpers.move_cursor { window = current_infoview.window, to = { 1, 0 } }

        current_infoview:move_cursor_to_goal(1)

        current_infoview:enter()
        assert.current_line.is '⊢ n = n'
        vim.api.nvim_set_current_win(lean_window)
      end)

      it('moves the cursor to a specific goal number', function()
        local current_infoview = infoview.get_current_infoview()

        current_infoview:enter()
        assert.current_line.is '⊢ n = n'
        vim.api.nvim_set_current_win(lean_window)

        current_infoview:move_cursor_to_goal(2)

        current_infoview:enter()
        assert.current_line.is '⊢ n = n ∨ n = 0 ∨ n = n✝ + 1'
        vim.api.nvim_set_current_win(lean_window)
      end)
    end
  )
)
