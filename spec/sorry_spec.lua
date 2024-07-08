local helpers = require 'spec.helpers'
local clean_buffer = helpers.clean_buffer

require('lean').setup {}

describe('sorry', function()
  it(
    'inserts sorries for each of multiple remaining goals',
    clean_buffer(
      [[
        example (p q : Prop) : p ∧ q ↔ q ∧ p := by
          constructor
      ]],
      function()
        helpers.wait_for_line_diagnostics()

        vim.cmd.normal { '2gg$', bang = true }
        require('lean.sorry').fill()
        assert.contents.are [[
          example (p q : Prop) : p ∧ q ↔ q ∧ p := by
            constructor
            · sorry
            · sorry
        ]]
      end
    )
  )

  it(
    'inserts a sorry for the remaining goal',
    clean_buffer('example (p : Prop) : p → p := by', function()
      helpers.wait_for_line_diagnostics()

      vim.cmd.normal { 'gg$', bang = true }
      require('lean.sorry').fill()
      assert.contents.are [[
          example (p : Prop) : p → p := by
            sorry
        ]]
    end)
  )

  it(
    'leaves the cursor in the first sorry',
    clean_buffer(
      [[
        def foo (p q : Prop) : p ∧ q ↔ q ∧ p := by
          constructor
      ]],
      function()
        helpers.wait_for_line_diagnostics()

        vim.cmd.normal { '2gg$', bang = true }
        require('lean.sorry').fill()
        vim.cmd.normal { 'cebar', bang = true }
        assert.contents.are [[
          def foo (p q : Prop) : p ∧ q ↔ q ∧ p := by
            constructor
            · bar
            · sorry
        ]]
      end
    )
  )

  it(
    'leaves the cursor in the only sorry',
    clean_buffer(
      [[
        def foo (p q : Prop) : p ∧ q →  q ∧ p := by
          intro h
      ]],
      function()
        helpers.wait_for_line_diagnostics()

        vim.cmd.normal { '2gg$', bang = true }
        require('lean.sorry').fill()
        vim.cmd.normal { 'cebar', bang = true }
        assert.contents.are [[
          def foo (p q : Prop) : p ∧ q →  q ∧ p := by
            intro h
            bar
        ]]
      end
    )
  )

  it(
    'indents sorry blocks when needed',
    clean_buffer(
      [[
        def foo (p q : Prop) : p ∧ q ↔ q ∧ p := by
          constructor

      ]],
      function()
        vim.cmd.normal { 'gg$', bang = true }
        helpers.wait_for_line_diagnostics()

        vim.cmd.normal { '3gg0', bang = true }
        require('lean.sorry').fill()
        assert.contents.are [[
          def foo (p q : Prop) : p ∧ q ↔ q ∧ p := by
            constructor

            · sorry
            · sorry
        ]]
      end
    )
  )

  it(
    'single goal within multiple goal block',
    clean_buffer(
      [[
        def foo (p q : Prop) : p ∧ q ↔ q ∧ p := by
          constructor
          · intro h
          · sorry
      ]],
      function()
        vim.cmd.normal { '3gg$', bang = true }
        helpers.wait_for_line_diagnostics()

        require('lean.sorry').fill()
        assert.contents.are [[
          def foo (p q : Prop) : p ∧ q ↔ q ∧ p := by
            constructor
            · intro h
              sorry
            · sorry
        ]]
      end
    )
  )

  it(
    'does nothing if there are no goals',
    clean_buffer(
      [[
        def foo (n : Nat) : n = n := by
          rfl
      ]],
      function()
        vim.cmd.normal { '2gg$', bang = true }
        require('lean.sorry').fill()
        assert.contents.are [[
          def foo (n : Nat) : n = n := by
            rfl
        ]]
      end
    )
  )
end)
