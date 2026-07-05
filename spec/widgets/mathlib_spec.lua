---@brief [[
--- Tests for widgets from Mathlib.
---@brief ]]

local with_widgets = require('spec.fixtures').with_widgets
local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

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

          Nothing selected. You can use gK or <C-LeftMouse> in the infoview to select expressions in the goal.
        ]]

        infoview.go_to()
        helpers.feed 'gK'

        assert.infoview_contents.are [[
          n : Nat
          ⊢ n = n

          ▼ Conv 🔍️
          Generate conv
        ]]

        helpers.search 'Generate'
        helpers.feed '<CR>'

        assert.infoview_contents.are [[
          n : Nat
          | n = n
        ]]

        -- We've jumped to the Lean window.
        assert.current_line.is '    skip'
      end,
      with_widgets
    )
  )

  it(
    'supports #click_suggestions widgets',
    helpers.clean_buffer(
      [[
        import Mathlib.Tactic.ClickSuggestions

        #click_suggestions

        def isUninteresting (x : Nat) := x ≠ 37

        example : isUninteresting 73 := by
          skip
      ]],
      function()
        helpers.search 'skip'
        assert.infoview_contents.are [[
          ⊢ isUninteresting 73

          Nothing selected. You can use gK or <C-LeftMouse> in the infoview to select expressions in the goal.
        ]]

        infoview.go_to()

        helpers.search 'Uninteresting'
        helpers.feed 'gK'
        helpers.wait:for_infoview_contents 'unfold'

        helpers.search 'unfold'
        helpers.feed '<CR>'
        helpers.wait:for_infoview_contents '≠'

        assert.has_all(infoview.get_current_infoview():get_lines(), {
          'Suggestions for isUninteresting 73',
          '[apply] 73 ≠ 37',
          '[apply] ¬73 = 37',
          '[apply] 73 = 37 → False',
        })

        helpers.search 'apply'
        helpers.feed '<CR>'

        -- we're back in the Lean buffer with the suggestion pasted in
        assert.contents.are [[
          import Mathlib.Tactic.ClickSuggestions

          #click_suggestions

          def isUninteresting (x : Nat) := x ≠ 37

          example : isUninteresting 73 := by
            rw [show isUninteresting 73 = (73 ≠ 37) from rfl]
            skip
        ]]
      end,
      with_widgets
    )
  )
end)
