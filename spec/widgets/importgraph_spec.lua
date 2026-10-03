---@brief [[
--- Tests for widgets from the ImportGraph Lean library.
---@brief ]]

local Buffer = require 'std.nvim.buffer'

local with_widgets = require('spec.fixtures').with_widgets
local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

describe('ImportGraph widgets', function()
  it(
    'supports GoToModule links',
    helpers.clean_buffer(
      [[
        import ImportGraph.Tools.FindHome
        import ImportGraph.Widget.GoToModule
        #find_home Nat.add_one
      ]],
      function()
        local initial = Buffer:current()

        helpers.search 'find_home'
        assert.infoview_contents.are [[
          ▼ 3:1-3:11: information:
          [Init.Prelude, Init.Grind.ToInt]
        ]]

        infoview.go_to()
        helpers.search 'Init'
        helpers.feed 'gd'

        assert.is_truthy(vim.wait(15000, function()
          return Buffer:current():name() ~= initial:name()
        end))

        local path = Buffer:current():name()
        assert.is_truthy(path:match 'Init/Prelude.lean')
      end,
      with_widgets
    )
  )
end)
