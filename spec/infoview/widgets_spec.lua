---@brief [[
---Tests for Lean's (user) widgets.
---@brief ]]

local Element = require('lean.tui').Element
local helpers = require 'spec.helpers'
local widgets = require 'lean.widgets'

require('lean').setup {}

describe('widgets', function()
  it(
    'can be registered for rendering',
    helpers.clean_buffer(
      [[
  import Lean
  @[widget_module]
  def helloWidget : Lean.Widget.Module where
    javascript := ""
  #widget helloWidget
  ]],
      function()
        helpers.move_cursor { to = { 5, 9 } }
        assert.infoview_contents.are [[
      ▶ expected type (5:9-5:20)
      ⊢ Lean.Widget.Module
    ]]

        widgets.implement('helloWidget', function(_)
          return Element:new { text = 'HELLO FROM WIDGET WORLD' }
        end)

        -- Move away and back to trigger re-rendering.
        helpers.move_cursor { to = { 4, 0 } }
        helpers.move_cursor { to = { 5, 9 } }

        assert.infoview_contents.are [[
          ▶ expected type (5:9-5:20)
          ⊢ Lean.Widget.Module

          HELLO FROM WIDGET WORLD
        ]]
      end
    )
  )

  it(
    'supports try this widgets with one suggestion',
    helpers.clean_buffer(
      [[
        example : 2 = 2 := by
          apply?
      ]],
      function()
        helpers.move_cursor { to = { 2, 0 } }
        assert.infoview_contents.are [[
          ⊢ 2 = 2

          ▶ 2:1-2:7: information:
          Try this: exact rfl

          ▶ suggestions:
          exact rfl
        ]]
      end
    )
  )

  it(
    'supports try this widgets with multiple suggestions',
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

          ▶ 10:25-10:39: information:
          Try this: trivial

          ▶ 10:25-10:39: information:
          Try this: rfl

          ▶ 10:22-10:39: error:
          unsolved goals
          ⊢ 37 = 37

          ▶ suggestions:
          trivial

          ▶ suggestions:
          rfl
        ]]
      end
    )
  )
end)
