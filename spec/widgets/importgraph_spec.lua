---@brief [[
--- Tests for widgets from the ImportGraph Lean library.
---@brief ]]

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
        local lean_window = vim.api.nvim_get_current_win()
        local initial_path = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())

        helpers.move_cursor { to = { 2, 2 } }
        assert.infoview_contents.are [[
          ▼ 2:1-2:11: information:
          [Init.Prelude]
        ]]

        infoview.go_to()
        helpers.move_cursor { to = { 2, 2 } }
        helpers.feed 'gd'

        assert.is_truthy(vim.wait(15000, function()
          return vim.api.nvim_buf_get_name(0) ~= initial_path
        end))

        local path = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(lean_window))
        assert.is_truthy(path:match 'Init/Prelude.lean')
      end
    )
  )
end)
