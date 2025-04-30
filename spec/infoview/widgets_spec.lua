---@brief [[
--- Tests for Lean's (user) widgets.
---@brief ]]

local helpers = require 'spec.helpers'
local testing_widgets = require('spec.fixtures').widgets

require('lean').setup {}

describe('widgets', function()
  package.path = package.path .. ';' .. testing_widgets .. '/?.lua'

  it(
    'can be registered via Lua modules on the package path',
    helpers.clean_buffer(
      [[
        import Lean
        @[widget_module]
        def helloWidget : Lean.Widget.Module where
          javascript := ""
        #widget helloWidget
      ]],
      function()
        -- (see the testing widget directory for the trivial implementation)
        helpers.move_cursor { to = { 5, 9 } }
        assert.infoview_contents.are [[
          ▼ expected type (5:9-5:20)
          ⊢ Lean.Widget.Module

          HELLO FROM WIDGET WORLD
        ]]
      end
    )
  )
end)
