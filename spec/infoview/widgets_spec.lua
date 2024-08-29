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
    'supports try this widgets',
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
end)
