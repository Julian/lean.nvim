---@brief [[
--- Tests for widgets from Lean core.
---@brief ]]

local Window = require 'std.nvim.window'

local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe('Lean core widgets', function()
  local lean_window = Window:current()

  it(
    'supports error description widgets',
    helpers.clean_buffer('def f := g', function()
      assert.infoview_contents.are [[
        ▼ 1:10-1:11: error:
        Unknown identifier `g`

        Error code: lean.unknownIdentifier
        View explanation
      ]]
    end)
  )

  it(
    'supports try this widgets with one suggestion',
    helpers.clean_buffer(
      [[
        example : 2 = 2 := by
          apply?
      ]],
      function()
        helpers.search 'apply'
        assert.infoview_contents.are [[
          Goals accomplished 🎉

          ⊢ 2 = 2

          ▼ 2:3-2:9: information:
          Try this:
            [apply] exact Nat.eq_of_beq_eq_true rfl
        ]]

        infoview.go_to()
        helpers.search 'apply] '
        helpers.feed '<CR>'

        -- the buffer contents have changed but we also jumped to the lean win
        assert.current_window.is(lean_window)
        assert.contents.are [[
          example : 2 = 2 := by
            exact Nat.eq_of_beq_eq_true rfl
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
        helpers.search 'xact'
        assert.infoview_contents.are [[
          Goals accomplished 🎉

          ▼ 1:62-1:68: information:
          Try this:
            [apply] exact ((fun a => a) ∘ fun a => a) rfl
        ]]

        infoview.go_to()
        helpers.search 'apply] '
        helpers.feed '<CR>'

        assert.current_window.is(lean_window)
        assert.contents.are [[
          example {𝔽 : Type} (x : 𝔽) (_ : 𝔽) (_ : 𝔽) : x = x := by exact
            ((fun a => a) ∘ fun a => a) rfl
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
        helpers.search [[  \zsfoo]]
        assert.infoview_contents.are [[
          ⊢ True

          ▼ 11:3-11:6: information:
          Try these:
            [apply] trivial
            [apply] sorry
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
        helpers.search [[by \zstwoSuggestions]]
        assert.infoview_contents.are [[
          ⊢ 37 = 37

          ▼ 10:25-10:39: information:
          Try this:
            [apply] trivial

          ▼ 10:25-10:39: information:
          Try this:
            [apply] rfl

          ▼ 10:22-10:39: error:
          unsolved goals
          ⊢ 37 = 37
        ]]
      end
    )
  )
end)
