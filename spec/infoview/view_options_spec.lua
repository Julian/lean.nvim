---@brief [[
--- Tests for infoview view_options, including use_widgets toggling.
---@brief ]]

local helpers = require 'spec.helpers'

local infoview = require 'lean.infoview'

require('lean').setup {}

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
