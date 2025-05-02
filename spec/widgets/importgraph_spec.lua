---@brief [[
--- Tests for widgets from the ImportGraph Lean library.
---@brief ]]

local Window = require 'std.nvim.window'

local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe('ImportGraph widgets', function()
  it(
    'supports GoToModule links',
    helpers.clean_buffer(
      [[
        import ImportGraph.Imports
        #find_home Nat.add_one
      ]],
      function()
        local lean_window = Window:current()
        local initial_buffer = lean_window:buffer()

        helpers.move_cursor { to = { 2, 2 } }
        assert.infoview_contents.are [[
          ▼ 2:1-2:11: information:
          [Init.Prelude]
        ]]

        infoview.go_to()
        helpers.move_cursor { to = { 2, 2 } }
        helpers.feed 'gd'

        assert.is_truthy(vim.wait(15000, function()
          return lean_window:buffer():name() ~= initial_buffer:name()
        end))

        local path = lean_window:buffer():name()
        assert.is_truthy(path:match 'Init/Prelude.lean')
      end
    )
  )
end)
