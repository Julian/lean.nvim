---@brief [[
--- Tests for widgets from the ImportGraph Lean library.
---@brief ]]

local Window = require 'std.nvim.window'

local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

---Open one of the ProofWidgets demos.
local function in_demo(name, fn)
  local jump = 'import ' .. name
  return helpers.clean_buffer(jump, function()
    local initial_path = vim.api.nvim_buf_get_name(0)
    Window:current():set_cursor { 1, #jump }
    helpers.wait_for_loading_pins()
    vim.lsp.buf.definition()
    assert.is_truthy(vim.wait(5000, function()
      return vim.api.nvim_buf_get_name(0) ~= initial_path
    end))
    fn()
  end)
end

describe('ProofWidgets widgets', function()
  it(
    'supports GoalTypePanel widgets',
    in_demo('ProofWidgets.Demos.ExprPresentation', function()
      helpers.search 'Place cursor here'
      assert.infoview_contents.are [[
        Goals accomplished 🎉

        ⊢ 2 + 2 = 4 ∧ 3 + 3 = 6

        ▼ Main goal type
        🐙 2 + 2 = 4 ∧ 3 + 3 = 6 🐙				With octopodes ▾
      ]]

      helpers.search 'rfl'
      assert.infoview_contents.are [[
        Goals accomplished 🎉

        ▼ 2 goals
        case left
        ⊢ 2 + 2 = 4

        case right
        ⊢ 3 + 3 = 6

        ▼ Main goal type
        🐙 2 + 2 = 4 🐙				With octopodes ▾
      ]]
    end)
  )

  describe('SelectionPanel widgets', function()
    it(
      'with no selection shows instructions',
      in_demo('ProofWidgets.Demos.ExprPresentation', function()
        helpers.search 'Place cursor here and select'
        assert.infoview_contents.are [[
          Goals accomplished 🎉

          _h : 2 + 2 = 5
          ⊢ 2 + 2 = 4

          Nothing selected. You can use gK in the infoview to select expressions in the goal.
        ]]
      end)
    )

    it(
      'with selected expressions',
      in_demo('ProofWidgets.Demos.ExprPresentation', function()
        helpers.search 'Place cursor here and select'
        assert.infoview_contents.are [[
          Goals accomplished 🎉

          _h : 2 + 2 = 5
          ⊢ 2 + 2 = 4

          Nothing selected. You can use gK in the infoview to select expressions in the goal.
        ]]

        infoview.go_to()

        helpers.search '_h'
        helpers.feed 'gK'

        assert.infoview_contents.are [[
          Goals accomplished 🎉

          _h : 2 + 2 = 5
          ⊢ 2 + 2 = 4

          ▼ Selected expressions:

          🐙 _h 🐙				With octopodes ▾
        ]]

        helpers.search '+ 2'
        helpers.feed 'gK'

        assert.infoview_contents.are [[
          Goals accomplished 🎉

          _h : 2 + 2 = 5
          ⊢ 2 + 2 = 4

          ▼ Selected expressions:

          🐙 _h 🐙				With octopodes ▾
          🐙 2 + 2 🐙				With octopodes ▾
        ]]

        helpers.search ' 4'
        helpers.feed 'gK'

        assert.infoview_contents.are [[
          Goals accomplished 🎉

          _h : 2 + 2 = 5
          ⊢ 2 + 2 = 4

          ▼ Selected expressions:

          🐙 _h 🐙				With octopodes ▾
          🐙 2 + 2 🐙				With octopodes ▾
          🐙 2 + 2 = 4 🐙				With octopodes ▾
        ]]
      end)
    )
  end)
end)
