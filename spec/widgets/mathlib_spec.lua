---@brief [[
--- Tests for widgets from Mathlib.
---@brief ]]

local with_widgets = require('spec.fixtures').with_widgets
local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe('Mathlib widgets', function()
  it(
    'supports conv? widgets',
    helpers.clean_buffer(
      [[
        import Mathlib.Tactic.Widget.Conv

        example {n : Nat} : n = n := by
          conv?
      ]],
      function()
        helpers.search 'conv?'
        assert.infoview_contents.are [[
          n : Nat
          ⊢ n = n

          Nothing selected. You can use gK in the infoview to select expressions in the goal.
        ]]

        infoview.go_to()
        helpers.feed 'gK'

        assert.infoview_contents.are [[
          n : Nat
          ⊢ n = n

          ▼ Conv 🔍
          Generate conv
        ]]

        helpers.search 'Generate'
        helpers.feed '<CR>'

        assert.infoview_contents.are [[
          n : Nat
          | n = n
        ]]

        -- We've jumped to the Lean window.
        assert.current_line.is '  conv =>'
      end,
      with_widgets
    )
  )

  it(
    'supports unfold? widgets',
    helpers.clean_buffer(
      [[
        import Mathlib.Tactic.Widget.InteractiveUnfold

        def isUninteresting (x : Nat) := x ≠ 37

        example : isUninteresting 73 := by
          unfold?
      ]],
      function()
        helpers.search 'unfold?'
        assert.infoview_contents.are [[
          ⊢ isUninteresting 73

          Nothing selected. You can use gK in the infoview to select expressions in the goal.
        ]]

        infoview.go_to()

        helpers.search 'Uninteresting'
        helpers.feed 'gK'
        helpers.wait_for_async_elements()

        assert.infoview_contents.are [[
          ⊢ isUninteresting 73

          ▼ Definitional rewrites:
          • 73 ≠ 37
          • ¬73 = 37
          • 73 = 37 → False
        ]]

        helpers.search '≠'
        helpers.feed '<CR>'

        -- we're back in the Lean buffer
        assert.contents.are [[
          import Mathlib.Tactic.Widget.InteractiveUnfold

          def isUninteresting (x : Nat) := x ≠ 37

          example : isUninteresting 73 := by
            rw [show isUninteresting 73 = (73 ≠ 37) from rfl]
        ]]
      end,
      with_widgets
    )
  )

  it(
    'supports rw?? widgets',
    helpers.clean_buffer(
      [[
        import Mathlib.Tactic.Widget.LibraryRewrite

        example (P Q : Prop) (h : P ↔ Q) : P → Q := by
          rw??
      ]],
      function()
        helpers.search 'rw??'
        helpers.wait_for_async_elements()
        assert.infoview_contents.are [[
          P Q : Prop
          h : P ↔ Q
          ⊢ P → Q

          Nothing selected. You can use gK in the infoview to select expressions in the goal.
        ]]

        infoview.go_to()
        helpers.search 'Q'
        helpers.feed 'gK'
        helpers.wait_for_async_elements()

        assert.infoview_contents.are [[
          37
        ]]

        helpers.feed '<CR>'
        helpers.wait_for_async_elements()

        assert.infoview_contents.are [[
          37
        ]]
      end,
      with_widgets
    )
  )
end)
