---@brief [[
--- Tests for semantic navigation in the infoview.
---@brief ]]

local Window = require 'std.nvim.window'

local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe('infoview navigation', function()
  describe(
    'goals',
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
        local current_infoview

        it('sets up a buffer with multiple goals', function()
          lean_window = Window:current()

          helpers.move_cursor { to = { 4, 3 } }
          current_infoview = infoview.get_current_infoview()
          helpers.wait_for_loading_pins(current_infoview)

          assert.matches('3 goals', current_infoview:get_line(0))
        end)

        it('go_to_goal moves to the first goal type, not the prefix', function()
          helpers.move_cursor {
            to = { 1, 0 },
            window = current_infoview.window,
          }

          infoview.go_to_goal()

          current_infoview:enter()
          assert.are.equal('n = n', current_infoview.window:rest_of_cursor_line())
          lean_window:make_current()
        end)

        it('next_goal moves to the goal type, not the prefix', function()
          infoview.go_to_goal(1)

          current_infoview:enter()
          assert.are.equal('n = n', current_infoview.window:rest_of_cursor_line())

          infoview.next_goal()
          assert.are.equal(
            'n = n ∨ n = 0 ∨ n = n✝ + 1',
            current_infoview.window:rest_of_cursor_line()
          )
          lean_window:make_current()
        end)

        it('next_goal moves from the second goal to the third', function()
          current_infoview:enter()
          local second_goal = vim.api.nvim_get_current_line()

          infoview.next_goal()
          local third_goal = vim.api.nvim_get_current_line()

          assert.are_not.equal(second_goal, third_goal)
          assert.matches('^⊢', third_goal)
          lean_window:make_current()
        end)

        it('next_goal does nothing at the last goal', function()
          current_infoview:enter()
          local current = vim.api.nvim_get_current_line()

          infoview.next_goal()

          assert.current_line.is(current)
          lean_window:make_current()
        end)

        it('prev_goal moves back through all goals', function()
          current_infoview:enter()

          infoview.prev_goal()
          local second_goal = vim.api.nvim_get_current_line()
          assert.matches('^⊢', second_goal)

          infoview.prev_goal()
          assert.current_line.is '⊢ n = n'
          lean_window:make_current()
        end)

        it('prev_goal does nothing at the first goal', function()
          current_infoview:enter()
          assert.current_line.is '⊢ n = n'

          infoview.prev_goal()
          assert.current_line.is '⊢ n = n'
          lean_window:make_current()
        end)

        it('next_goal works repeatedly to traverse all goals', function()
          infoview.go_to_goal(1)

          current_infoview:enter()
          assert.current_line.is '⊢ n = n'

          local goals = { vim.api.nvim_get_current_line() }
          for _ = 1, 3 do
            infoview.next_goal()
            local line = vim.api.nvim_get_current_line()
            table.insert(goals, line)
          end

          assert.are_not.equal(goals[1], goals[2])
          assert.are_not.equal(goals[2], goals[3])
          assert.are.equal(goals[3], goals[4]) -- stayed at last

          lean_window:make_current()
        end)
      end
    )
  )

  describe(
    'hypotheses',
    helpers.clean_buffer(
      [[
    example (a : Nat) (b : String) (c : Bool) : True := by
      sorry
    ]],
      function()
        local lean_window
        local current_infoview

        it('sets up a buffer with hypotheses', function()
          lean_window = Window:current()

          helpers.search 'sorry'
          current_infoview = infoview.get_current_infoview()
          helpers.wait_for_loading_pins(current_infoview)
        end)

        it('navigates forward through hypotheses then back', function()
          current_infoview:enter()

          helpers.move_cursor { to = { 1, 0 }, window = current_infoview.window }

          assert.matches('^a', vim.api.nvim_get_current_line())

          infoview.next_hypothesis()
          assert.matches('^b', vim.api.nvim_get_current_line())

          infoview.next_hypothesis()
          assert.matches('^c', vim.api.nvim_get_current_line())

          -- No more hypotheses.
          infoview.next_hypothesis()
          assert.matches('^c', vim.api.nvim_get_current_line())

          -- Now go back.
          infoview.prev_hypothesis()
          assert.matches('^b', vim.api.nvim_get_current_line())

          infoview.prev_hypothesis()
          assert.matches('^a', vim.api.nvim_get_current_line())

          -- No earlier hypotheses.
          infoview.prev_hypothesis()
          assert.matches('^a', vim.api.nvim_get_current_line())

          lean_window:make_current()
        end)
      end
    )
  )

  describe(
    'hypotheses across goals',
    helpers.clean_buffer(
      [[
    example (a : Nat) (b : Nat) (h : a < b) : a ≤ b ∧ a ≠ b := by
      constructor
      · sorry
      · sorry
    ]],
      function()
        local lean_window
        local current_infoview

        it('sets up a buffer with multiple goals', function()
          lean_window = Window:current()

          helpers.move_cursor { to = { 2, 3 } }
          current_infoview = infoview.get_current_infoview()
          helpers.wait_for_loading_pins(current_infoview)

          assert.matches('2 goals', current_infoview:get_line(0))
        end)

        it('prev_hypothesis from the second goal lands on the last hyp of the first', function()
          current_infoview:enter()

          -- Navigate to the first hypothesis of the second goal.
          helpers.move_cursor { to = { 1, 0 }, window = current_infoview.window }
          for _ = 1, 3 do
            infoview.next_hypothesis()
          end

          -- We should now be on the first hyp of the second goal.
          local line = vim.api.nvim_get_current_line()
          assert.matches('^a', line)
          local pos_second_goal = current_infoview.window:cursor()

          -- Confirm this is really the second goal's hyp, not the first's.
          local first_hyp_pos = { 1, 0 }
          helpers.move_cursor { to = first_hyp_pos, window = current_infoview.window }
          infoview.next_hypothesis()
          local first_goal_a = current_infoview.window:cursor()
          assert.are_not.same(first_goal_a, pos_second_goal)

          -- Now go back to the second goal's first hypothesis.
          helpers.move_cursor { to = pos_second_goal, window = current_infoview.window }

          -- prev_hypothesis should go to h : a < b in the first goal,
          -- NOT a b : Nat.
          infoview.prev_hypothesis()
          assert.matches('^h', vim.api.nvim_get_current_line())

          lean_window:make_current()
        end)
      end
    )
  )

  describe(
    'suggestions and links',
    helpers.clean_buffer(
      [[
    example : 2 = 2 := by
      apply?
    ]],
      function()
        local lean_window
        local current_infoview

        it('sets up a buffer with suggestions', function()
          lean_window = Window:current()
          helpers.wait_for_diagnostics()
          helpers.search 'apply'

          current_infoview = infoview.get_current_infoview()
          helpers.wait_for_loading_pins(current_infoview)
        end)

        it('next_suggestion navigates to a suggestion', function()
          current_infoview:enter()

          helpers.move_cursor { to = { 1, 0 }, window = current_infoview.window }

          infoview.next_suggestion()
          assert.matches('exact', vim.api.nvim_get_current_line())
          lean_window:make_current()
        end)

        it('go_to_suggestion moves to the first suggestion', function()
          current_infoview:enter()

          helpers.move_cursor { to = { 1, 0 }, window = current_infoview.window }

          infoview.go_to_suggestion()
          assert.matches('exact', vim.api.nvim_get_current_line())
          lean_window:make_current()
        end)

        it('accept_suggestion does not move the infoview cursor', function()
          current_infoview:enter()

          helpers.move_cursor { to = { 1, 0 }, window = current_infoview.window }
          local cursor_before = current_infoview.window:cursor()

          lean_window:make_current()
          infoview.accept_suggestion()

          local cursor_after = current_infoview.window:cursor()
          assert.are.same(cursor_before, cursor_after)
        end)

        it('next_link navigates to a link', function()
          current_infoview:enter()

          helpers.move_cursor { to = { 1, 0 }, window = current_infoview.window }

          infoview.next_link()
          assert.matches('exact', vim.api.nvim_get_current_line())
          lean_window:make_current()
        end)
      end
    )
  )
end)
