---@brief [[
--- Tests for customizing the goal headers shown in the infoview via
--- `infoview.messages.goals`.
---@brief ]]

local helpers = require 'spec.helpers'

vim.g.lean_config = vim.tbl_deep_extend('force', vim.g.lean_config, {
  progress_bars = { enable = false },
  infoview = {
    messages = {
      goals = {
        accomplished = 'PROVEN!',
        none = 'nothing to do here',
        -- Unlike the default, also give a lone goal a header, exercising that
        -- `some` covers n ≥ 1 (not just n > 1).
        some = function(n)
          return ('there are %d goals'):format(n)
        end,
      },
    },
  },
})

describe('infoview.messages.goals', function()
  it(
    'shows the custom accomplished message on a solved goal',
    helpers.clean_buffer([[example : 37 = 37 := by rfl]], function()
      assert.infoview_contents_at({ 1, 26 }).are 'PROVEN!'
    end)
  )

  it(
    'shows the custom no-goals message between goals',
    helpers.clean_buffer(
      [[
        example : 37 = 37 := by rfl

        example : 12 = 12 := rfl
      ]],
      function()
        assert.infoview_contents_at({ 2, 0 }).are 'nothing to do here'
      end
    )
  )

  it(
    'shows a custom header for a single goal',
    helpers.clean_buffer(
      [[
        example : 37 = 37 := by
          sorry
      ]],
      function()
        assert.infoview_contents_at('sorry').are [[
          ▼ there are 1 goals
          ⊢ 37 = 37
        ]]
      end
    )
  )

  it(
    'shows a custom header for multiple goals',
    helpers.clean_buffer(
      [[
        example (n : Nat) : n = n := by
          cases n
          · sorry
          · sorry
      ]],
      function()
        assert.infoview_contents_at({ 2, 3 }).are [[
          ▼ there are 2 goals
          case zero
          ⊢ 0 = 0

          case succ
          n✝ : Nat
          ⊢ n✝ + 1 = n✝ + 1
        ]]
      end
    )
  )
end)
