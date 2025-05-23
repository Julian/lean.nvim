---@brief [[
--- Tests for widgets from Lean core.
---@brief ]]

local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe('Lean core widgets', function()
  it(
    'supports try this widgets with one suggestion',
    helpers.clean_buffer(
      [[
        example : 2 = 2 := by
          apply?
      ]],
      function()
        helpers.move_cursor { to = { 2, 2 } }
        assert.infoview_contents.are [[
          Goals accomplished 🎉

          ⊢ 2 = 2

          ▼ suggestion:
          exact rfl

          ▼ 2:3-2:9: information:
          Try this: exact rfl
        ]]

        infoview.go_to()
        helpers.move_cursor { to = { 6, 1 } }
        helpers.feed '<CR>'

        -- the buffer contents have changed but we also jumped to the lean win
        assert.contents.are [[
          example : 2 = 2 := by
            exact rfl
        ]]
      end
    )
  )

  it(
    'replaces ranges without being confused by unicode',
    helpers.clean_buffer(
      [[
        example {𝔽 : Type} (x : 𝔽) (_ : 𝔽) (_ : 𝔽) : x = x := by exact?
      ]],
      function()
        helpers.move_cursor { to = { 1, 100 } }
        assert.infoview_contents.are [[
          Goals accomplished 🎉

          ▼ suggestion:
          exact rfl

          ▼ 1:62-1:68: information:
          Try this: exact rfl
        ]]

        infoview.go_to()
        helpers.move_cursor { to = { 4, 1 } }
        helpers.feed '<CR>'

        assert.contents.are [[
          example {𝔽 : Type} (x : 𝔽) (_ : 𝔽) (_ : 𝔽) : x = x := by exact rfl
        ]]
      end
    )
  )

  it(
    'supports try this widgets with simultaneously added multiple suggestions',
    helpers.clean_buffer(
      [[
        import Lean.Meta.Tactic.TryThis

        open Lean Elab Tactic in
        elab "foo" : tactic => do
          Lean.Meta.Tactic.TryThis.addSuggestions (← getRef)
            #[.suggestion "trivial",
              .suggestion "sorry"]
          evalTactic (← `(tactic|sorry))

        example : True := by
          foo
      ]],
      function()
        helpers.move_cursor { to = { 11, 2 } }
        assert.infoview_contents.are [[
          ⊢ True

          ▼ suggestion:
          trivial
          sorry

          ▼ 11:3-11:6: information:
          Try these:
          • trivial
          • sorry
        ]]
      end
    )
  )

  it(
    'supports try this widgets with separately added multiple suggestions',
    helpers.clean_buffer(
      [[
        import Lean.Meta.Tactic.TryThis

        namespace Lean.Meta.Tactic.TryThis
        open Lean Elab Tactic

        elab "twoSuggestions" : tactic => do
          addSuggestion (← getRef) (← `(tactic| trivial))
          addSuggestion (← getRef) (← `(tactic| rfl))

        example : 37 = 37 := by twoSuggestions

        end Lean.Meta.Tactic.TryThis
      ]],
      function()
        helpers.move_cursor { to = { 10, 28 } }
        assert.infoview_contents.are [[
          ⊢ 37 = 37

          ▼ suggestion:
          trivial

          ▼ suggestion:
          rfl

          ▼ 10:25-10:39: information:
          Try this: trivial

          ▼ 10:25-10:39: information:
          Try this: rfl

          ▼ 10:22-10:39: error:
          unsolved goals
          ⊢ 37 = 37
        ]]
      end
    )
  )
end)
