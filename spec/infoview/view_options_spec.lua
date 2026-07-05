---@brief [[
--- Tests for infoview view_options, including use_widgets toggling.
---@brief ]]

local Tab = require 'std.nvim.tab'

local helpers = require 'spec.helpers'

local infoview = require 'lean.infoview'

describe('infoview view_options', function()
  describe('use_widgets', function()
    it(
      'defaults to interactive widgets',
      helpers.clean_buffer(
        [[
          example (h: 73 = 73) : 37 = 37 := by
            sorry
        ]],
        function()
          helpers.search 'sorry'
          local iv = infoview.get_current_infoview()
          assert.is_true(iv.view_options.use_widgets)
          assert.infoview_contents.are [[
            h : 73 = 73
            ⊢ 37 = 37
          ]]
        end
      )
    )

    it(
      'can be disabled and re-enabled at runtime',
      helpers.clean_buffer(
        [[
          example : 37 = 37 := by
            sorry
        ]],
        function()
          infoview.enable_widgets()
          local iv = infoview.get_current_infoview()
          assert.is_true(iv.view_options.use_widgets)

          infoview.disable_widgets()
          assert.is_false(iv.view_options.use_widgets)

          infoview.enable_widgets()
          assert.is_true(iv.view_options.use_widgets)
        end
      )
    )
  end)

  it(
    'can hide inaccessible names, even shadowed ones with indices',
    helpers.clean_buffer(
      [[
        example : Nat → Nat → Nat → 37 = 37 := by
          intro n n n
          sorry
      ]],
      function()
        helpers.search 'sorry'
        assert.infoview_contents.are [[
          n✝¹ n✝ n : Nat
          ⊢ 37 = 37
        ]]

        local iv = infoview.get_current_infoview()
        iv.view_options.show_hidden_assumptions = false
        iv.pin:update()
        assert.infoview_contents.are [[
          n : Nat
          ⊢ 37 = 37
        ]]

        iv.view_options.show_hidden_assumptions = true
      end
    )
  )

  it(
    'can be selected interactively via <LocalLeader>v from a Lean buffer',
    helpers.clean_buffer(
      [[
        example : 37 = 37 := by
          sorry
      ]],
      function()
        local known_windows = Tab:current():windows()
        helpers.feed '<LocalLeader>v'
        local popup = helpers.wait_for_new_window(known_windows)
        popup:close()
      end
    )
  )

  it(
    'can be selected interactively via <LocalLeader>v from the infoview',
    helpers.clean_buffer(
      [[
        example : 37 = 37 := by
          sorry
      ]],
      function()
        vim.cmd.LeanGotoInfoview()
        local known_windows = Tab:current():windows()
        helpers.feed '<LocalLeader>v'
        local popup = helpers.wait_for_new_window(known_windows)
        popup:close()
      end
    )
  )

  it(
    'are initialized from config defaults on the infoview object',
    helpers.clean_buffer(
      [[
        example : 37 = 37 := by
          sorry
      ]],
      function()
        infoview.enable_widgets()
        local iv = infoview.get_current_infoview()
        assert.are.same({
          use_widgets = true,
          show_types = true,
          show_instances = true,
          show_hidden_assumptions = true,
          show_let_values = true,
          show_term_goals = true,
          reverse = false,
        }, iv.view_options)
      end
    )
  )
end)
