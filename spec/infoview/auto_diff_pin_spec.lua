---@brief [[
--- Tests for the auto-diff pin feature.
---
--- The auto-diff pin automatically sets the diff pin to the *previous* cursor
--- position on every cursor move, so the diff window always shows "where you
--- just were" while the main infoview shows the current position.
---@brief ]]

local Window = require 'std.nvim.window'

local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

-- Use the same fixture as the diff pin tests so goal strings are known.
describe(
  'auto-diff pin',
  helpers.clean_buffer(
    [[
      theorem has_tactic_goal : p ∨ q → q ∨ p := by
        intro h
        cases h with
        | inl h37 =>
          apply Or.inr
          exact h37
        | inr h2 =>
          apply Or.inl
          sorry
    ]],
    function()
      local lean_window

      -- Two positions with known, distinct goal states.
      local pos_inl = { 4, 5 } -- `| inl h37 =>`: case inl goal + expected type
      local pos_inl_h = { 5, 5 } -- `apply Or.inr`: case inl.h, ⊢ p

      it('shows previous position in diff when cursor moves', function()
        lean_window = Window:current()
        helpers.wait:for_processing()

        helpers.move_cursor { to = pos_inl }
        assert.infoview_contents.are [[
          case inl
          p q : Prop
          h37 : p
          ⊢ q ∨ p

          ▼ expected type (4:5-4:8)
          ⊢ ∀ {a b : Prop}, a → a ∨ b
        ]]

        -- Enable auto-diff. The diff pin is immediately set to the current position.
        infoview.toggle_auto_diff_pin(true)
        helpers.wait_for_new_window { lean_window, infoview.get_current_infoview().window }
        helpers.wait:for_ready_infoview()

        assert.diff_contents.are [[
          case inl
          p q : Prop
          h37 : p
          ⊢ q ∨ p

          ▼ expected type (4:5-4:8)
          ⊢ ∀ {a b : Prop}, a → a ∨ b
        ]]

        -- Move to a new position with a different goal.
        helpers.move_cursor { to = pos_inl_h }
        assert.infoview_contents.are [[
          case inl.h
          p q : Prop
          h37 : p
          ⊢ p
        ]]

        -- Diff should now show where we just were (pos_inl).
        assert.diff_contents.are [[
          case inl
          p q : Prop
          h37 : p
          ⊢ q ∨ p

          ▼ expected type (4:5-4:8)
          ⊢ ∀ {a b : Prop}, a → a ∨ b
        ]]
      end)

      it('tracks the previous position as the cursor keeps moving', function()
        -- Move back to pos_inl: diff should update to pos_inl_h's content.
        helpers.move_cursor { to = pos_inl }
        assert.infoview_contents.are [[
          case inl
          p q : Prop
          h37 : p
          ⊢ q ∨ p

          ▼ expected type (4:5-4:8)
          ⊢ ∀ {a b : Prop}, a → a ∨ b
        ]]

        assert.diff_contents.are [[
          case inl.h
          p q : Prop
          h37 : p
          ⊢ p
        ]]
      end)

      it('closes the diff window when toggled off with clear', function()
        local current_infoview = infoview.get_current_infoview()
        assert.is.equal(3, #vim.api.nvim_tabpage_list_wins(0))

        infoview.toggle_auto_diff_pin(true)

        assert.windows.are { lean_window, current_infoview.window }
      end)

      it('stops tracking after being disabled', function()
        -- Auto-diff is now off. Re-enable it briefly to get a diff window, then
        -- disable without clearing so we can verify tracking has stopped.
        helpers.move_cursor { to = pos_inl }
        infoview.toggle_auto_diff_pin(false)
        helpers.wait_for_new_window { lean_window, infoview.get_current_infoview().window }

        helpers.move_cursor { to = pos_inl_h }
        assert.infoview_contents.are [[
          case inl.h
          p q : Prop
          h37 : p
          ⊢ p
        ]]

        -- Disable without clearing. Diff should be frozen at pos_inl.
        infoview.toggle_auto_diff_pin(false)

        -- Move the cursor: diff should not update.
        helpers.move_cursor { to = pos_inl }
        assert.infoview_contents.are [[
          case inl
          p q : Prop
          h37 : p
          ⊢ q ∨ p

          ▼ expected type (4:5-4:8)
          ⊢ ∀ {a b : Prop}, a → a ∨ b
        ]]

        assert.diff_contents.are [[
          case inl
          p q : Prop
          h37 : p
          ⊢ q ∨ p

          ▼ expected type (4:5-4:8)
          ⊢ ∀ {a b : Prop}, a → a ∨ b
        ]]
      end)

      it('keeps the diff window when toggled off without clear', function()
        assert.is.equal(3, #vim.api.nvim_tabpage_list_wins(0))
      end)

      it('resumes tracking when re-enabled', function()
        -- Currently at pos_inl with auto-diff off and diff showing pos_inl.
        -- Re-enable: diff should immediately capture pos_inl (current position).
        infoview.toggle_auto_diff_pin(false)
        helpers.wait:for_ready_infoview()

        -- Move to pos_inl_h: diff should update to pos_inl.
        helpers.move_cursor { to = pos_inl_h }
        assert.infoview_contents.are [[
          case inl.h
          p q : Prop
          h37 : p
          ⊢ p
        ]]

        assert.diff_contents.are [[
          case inl
          p q : Prop
          h37 : p
          ⊢ q ∨ p

          ▼ expected type (4:5-4:8)
          ⊢ ∀ {a b : Prop}, a → a ∨ b
        ]]
      end)
    end
  )
)
