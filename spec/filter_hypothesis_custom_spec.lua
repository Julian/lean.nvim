local helpers = require 'spec.helpers'

require('lean').setup {}

---@type lean.Config
vim.g.lean_config = {
  infoview = {
    view_options = {
      show_types = false,
      reverse = true,
    },
  },
}

describe(
  'filter_hypothesis',
  helpers.clean_buffer(
    [[
  example {A : Type} (n : Nat) (b : 3 = 3) (c : 4 = 4) : n = n ∨ n = 37 := by
    left
    rfl
  ]],
    function()
      it('filters hypotheses', function()
        helpers.move_cursor { to = { 2, 2 } }

        vim.b.lean_test_ignore_whitespace = true
        assert.infoview_contents.are [[
          case h
          ⊢ n = n
          c : 4 = 4
          b : 3 = 3
          n : Nat
        ]]
      end)
    end
  )
)
