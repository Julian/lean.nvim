---@brief [[
--- Tests for widgets from the ProofWidgets Lean library.
---@brief ]]

local Window = require 'std.nvim.window'

local fixtures = require 'spec.fixtures'
local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

package.path = package.path .. ';' .. fixtures.widgets .. '/?.lua'

---Open one of the ProofWidgets demos.
local function in_demo(name, fn)
  local jump = 'import ' .. name
  return helpers.clean_buffer(jump, function()
    local initial_path = vim.api.nvim_buf_get_name(0)
    Window:current():set_cursor { 1, #jump }
    helpers.wait:for_ready_infoview()
    vim.lsp.buf.definition()
    assert.is_truthy(vim.wait(5000, function()
      return vim.api.nvim_buf_get_name(0) ~= initial_path
    end))
    fn()
  end, fixtures.with_widgets)
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

  it(
    'supports HtmlDisplayPanel widgets',
    in_demo('ProofWidgets.Demos.Jsx', function()
      helpers.search '#html <b>What, HTML in Lean?!'
      assert.infoview_contents.are [[
        ▼ HTML Display
        What, HTML in Lean?!
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

        helpers.feed '<Esc>'
        assert.infoview_contents.are [[
          Goals accomplished 🎉

          _h : 2 + 2 = 5
          ⊢ 2 + 2 = 4

          Nothing selected. You can use gK in the infoview to select expressions in the goal.
        ]]
      end)
    )
  end)

  it(
    'supports RefreshComponent widgets',
    helpers.clean_buffer(
      [[
        import WithWidgets.RefreshWidget

        #html quickRefresh
      ]],
      function()
        helpers.search '#html quickRefresh'
        helpers.wait:for_infoview_contents 'refreshed!'
      end,
      fixtures.with_widgets
    )
  )

  it(
    'supports MarkdownDisplay widgets',
    helpers.clean_buffer(
      [[
        import WithWidgets.MarkdownWidget

        #html quickMarkdown
      ]],
      function()
        helpers.search '#html quickMarkdown'
        assert.infoview_contents.are [[
          ▼ HTML Display
          Hello **markdown**
        ]]
      end,
      fixtures.with_widgets
    )
  )

  it(
    'supports InteractiveExpr widgets',
    helpers.clean_buffer(
      [[
        import WithWidgets.InteractiveExprWidget

        #html quickExpr
      ]],
      function()
        helpers.search '#html quickExpr'
        assert.infoview_contents.are [[
          ▼ HTML Display
          1 + 2
        ]]
      end,
      fixtures.with_widgets
    )
  )

  it(
    'supports FilterDetails widgets',
    helpers.clean_buffer(
      [[
        import WithWidgets.FilterDetailsWidget

        #html quickFilter
      ]],
      function()
        helpers.search '#html quickFilter'
        assert.infoview_contents.are [[
          ▼ HTML Display
          Summary
          filtered content
        ]]
      end,
      fixtures.with_widgets
    )
  )

  it(
    'preserves whitespace inside <pre> but collapses it outside',
    helpers.clean_buffer(
      [[
        import WithWidgets.PreWidget

        #html quickPre
      ]],
      function()
        helpers.search '#html quickPre'
        assert.infoview_contents.are [[
          ▼ HTML Display

          hello
            indented
              world
          hello indented world
        ]]
      end,
      fixtures.with_widgets
    )
  )

  describe('panel widgets with null JSON props', function()
    -- Some widgets (e.g. Verbose Lean) call savePanelWidgetInfo with
    -- Json.null props, which Neovim decodes to vim.NIL (truthy userdata).
    -- This must not crash the panel wrapper's vim.tbl_extend call.
    it(
      'renders without crashing when widget props are null',
      helpers.clean_buffer(
        [[
          import WithWidgets.NullPropsWidget

          example (_h : True) : True := by
            null_props_widget
            trivial
        ]],
        function()
          helpers.search 'null_props_widget'

          assert.infoview_contents.are [[
            Goals accomplished 🎉

            _h : True
            ⊢ True

            Nothing selected. You can use gK in the infoview to select expressions in the goal.
          ]]

          infoview.go_to()

          helpers.search '_h'
          helpers.feed 'gK'

          assert.infoview_contents.are [[
            Goals accomplished 🎉

            _h : True
            ⊢ True

            PANEL WIDGET WITH 1 SELECTIONS
          ]]
        end,
        fixtures.with_widgets
      )
    )
  end)
end)
