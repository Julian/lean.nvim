---@brief [[
--- Tests for the generic mk_rpc_widget% handler.
---@brief ]]

local with_widgets = require('spec.fixtures').with_widgets
local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe('generic mk_rpc_widget%', function()
  it(
    'renders a widget with no Lua module via ofRpcMethod',
    helpers.clean_buffer(
      [[
        import WithWidgets.GenericRpcWidget

        example (n : Nat) : n = n := by
          with_panel_widgets [GenericRpcWidget]
            sorry
      ]],
      function()
        helpers.search 'sorry'
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

          ▼ Generic RPC Widget
          Selected 1 location(s).
        ]]
      end,
      with_widgets
    )
  )
end)
