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
end)
