local helpers = require 'spec.helpers'

require('lean').setup {}

---@type lean.Config
vim.g.lean_config = {
  infoview = {
    filter_hypothesis = function(hyp)
      return not hyp.isType and not vim.deep_equal(hyp.names, { 'b' })
    end,
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

        assert.infoview_contents.are [[
      case h
      n : Nat
      c : 4 = 4
      ⊢ n = n
    ]]
      end)
    end
  )
)
