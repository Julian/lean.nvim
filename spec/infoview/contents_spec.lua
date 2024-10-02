---@brief [[
--- Tests for the infoview when interactive widgets are enabled.
---@brief ]]

local helpers = require 'spec.helpers'

require('lean').setup {}

describe('interactive infoview', function()
  it(
    'shows no goals',
    helpers.clean_buffer([[example : 37 = 37 := by rfl]], function()
      helpers.move_cursor { to = { 1, 26 } }
      assert.infoview_contents.are '▶ goals accomplished 🎉'
    end)
  )

  it(
    'shows a tactic goal with no hypotheses',
    helpers.clean_buffer(
      [[
      example : 37 = 37 := by
        sorry
    ]],
      function()
        helpers.move_cursor { to = { 2, 0 } }
        assert.infoview_contents.are '⊢ 37 = 37'
      end
    )
  )

  it(
    'shows a tactic goal with one hypothesis',
    helpers.clean_buffer(
      [[
      example (h: 73 = 73) : 37 = 37 := by
        sorry
    ]],
      function()
        helpers.move_cursor { to = { 2, 0 } }
        assert.infoview_contents.are [[
      h : 73 = 73
      ⊢ 37 = 37
    ]]
      end
    )
  )

  it(
    'shows a tactic goal with multiple hypotheses',
    helpers.clean_buffer(
      [[
      example {A: Type} (a : A) (h: a = a) : 37 = 37 := by
        sorry
    ]],
      function()
        helpers.move_cursor { to = { 2, 0 } }
        assert.infoview_contents.are [[
      A : Type
      a : A
      h : a = a
      ⊢ 37 = 37
    ]]
      end
    )
  )

  it(
    'shows a named tactic goal',
    helpers.clean_buffer(
      [[
      example (n : Nat) : n = n := by
        cases n
        · rfl
        · rfl
    ]],
      function()
        helpers.move_cursor { to = { 3, 3 } }
        assert.infoview_contents.are [[
      case zero
      ⊢ 0 = 0
    ]]
      end
    )
  )

  it(
    'shows multiple named tactic goals',
    helpers.clean_buffer(
      [[
      example (n : Nat) : n = n := by
        cases n
        · rfl
        · rfl
    ]],
      function()
        helpers.move_cursor { to = { 2, 3 } }
        assert.infoview_contents.are [[
      ▶ 2 goals
      case zero
      ⊢ 0 = 0

      case succ
      n✝ : Nat
      ⊢ n✝ + 1 = n✝ + 1
    ]]
      end
    )
  )

  it(
    'shows a term goal with no hypotheses',
    helpers.clean_buffer([[def n : Nat := 37]], function()
      helpers.move_cursor { to = { 1, 17 } }
      assert.infoview_contents.are [[
      ▶ expected type (1:16-1:18)
      ⊢ Nat
    ]]
    end)
  )

  it(
    'shows a term goal with one hypothesis',
    helpers.clean_buffer([[def n (x : Nat) : Nat := x]], function()
      helpers.move_cursor { to = { 1, 26 } }
      assert.infoview_contents.are [[
      ▶ expected type (1:26-1:27)
      x : Nat
      ⊢ Nat
    ]]
    end)
  )

  it(
    'shows a term goal with multiple hypotheses',
    helpers.clean_buffer([[def n (A : Type) (a : A) : A := a]], function()
      helpers.move_cursor { to = { 1, 34 } }
      assert.infoview_contents.are [[
      ▶ expected type (1:33-1:34)
      A : Type
      a : A
      ⊢ A
    ]]
    end)
  )

  it(
    'shows mixed tactic and term goals',
    helpers.clean_buffer(
      [[
      example : 37 = 37 := by
        have : Nat := 37
        rfl
    ]],
      function()
        helpers.move_cursor { to = { 2, 18 } }
        assert.infoview_contents.are [[
      this : Nat
      ⊢ 37 = 37

      ▶ expected type (2:15-2:17)
      ⊢ Nat
    ]]
      end
    )
  )

  it(
    'shows mixed tactic and term goals with names',
    helpers.clean_buffer(
      [[
      example (n : Nat) : n = n := by
        cases n
        · rfl
        · rfl
    ]],
      function()
        helpers.move_cursor { to = { 2, 6 } }
        assert.infoview_contents.are [[
      ▶ 2 goals
      case zero
      ⊢ 0 = 0

      case succ
      n✝ : Nat
      ⊢ n✝ + 1 = n✝ + 1

      ▶ expected type (2:7-2:8)
      n : Nat
      ⊢ Nat
    ]]
      end
    )
  )

  it(
    'shows goals with multibyte characters',
    helpers.clean_buffer([[def multibyte {𝔽 : Type} : 𝔽 = 𝔽 := rfl]], function()
      helpers.move_cursor { to = { 1, 48 } }
      assert.infoview_contents.are [[
      ▶ expected type (1:40-1:43)
      𝔽 : Type
      ⊢ 𝔽 = 𝔽
    ]]

      helpers.move_cursor { to = { 1, 44 } }
      assert.infoview_contents.are [[
    ]]

      helpers.move_cursor { to = { 1, 46 } }
      assert.infoview_contents.are [[
      ▶ expected type (1:40-1:43)
      𝔽 : Type
      ⊢ 𝔽 = 𝔽
    ]]
    end)
  )

  describe('diagnostics', function()
    it(
      'shows info messages',
      helpers.clean_buffer(
        [[
        import Lean
        elab "#testing123" : command => Lean.logInfo "Hello"
        #testing123
      ]],
        function()
          helpers.move_cursor { to = { 3, 2 } }
          assert.infoview_contents.are [[
            ▶ 3:1-3:12: information:
            Hello
        ]]
        end
      )
    )

    it(
      'shows warning messages',
      helpers.clean_buffer(
        [[
        import Lean
        elab "#testing123" : command => Lean.logWarning "Hmm..."
        #testing123
      ]],
        function()
          helpers.move_cursor { to = { 3, 2 } }
          assert.infoview_contents.are [[
            ▶ 3:1-3:12: warning:
            Hmm...
        ]]
        end
      )
    )

    it(
      'shows error messages',
      helpers.clean_buffer(
        [[
        import Lean
        elab "#testing123" : command => Lean.logError "Uh oh!"
        #testing123
      ]],
        function()
          helpers.move_cursor { to = { 3, 2 } }
          assert.infoview_contents.are [[
            ▶ 3:1-3:12: error:
            Uh oh!
        ]]
        end
      )
    )

    it(
      'shows multiline messages which do not terminate in newlines',
      helpers.clean_buffer(
        [[
        import Lean
        elab "#testing123" : command => do
          Lean.logInfo "Multiple\nLine\nMessage"
          Lean.logInfo "Another"
        #testing123
      ]],
        function()
          helpers.move_cursor { to = { 5, 2 } }
          assert.infoview_contents.are [[
            ▶ 5:1-5:12: information:
            Multiple
            Line
            Message

            ▶ 5:1-5:12: information:
            Another
        ]]
        end
      )
    )

    it(
      'shows multiline messages which do terminate in newlines',
      helpers.clean_buffer(
        [[
        import Lean
        elab "#testing123" : command => do
          Lean.logInfo "Multiple\nLines\n"
          Lean.logInfo "Another"
        #testing123
      ]],
        function()
          helpers.move_cursor { to = { 5, 2 } }
          assert.infoview_contents.are [[
            ▶ 5:1-5:12: information:
            Multiple
            Lines


            ▶ 5:1-5:12: information:
            Another
        ]]
        end
      )
    )

    it(
      'shows multiple messages',
      helpers.clean_buffer(
        [[
        import Lean
        elab "#testing123" : command => do
          Lean.logInfo "So"
          Lean.logWarning "Many..."
          Lean.logError "Messages!"
        #testing123
      ]],
        function()
          helpers.move_cursor { to = { 6, 1 } }
          assert.infoview_contents.are [[
            ▶ 6:1-6:12: information:
            So

            ▶ 6:1-6:12: warning:
            Many...

            ▶ 6:1-6:12: error:
            Messages!
        ]]
        end
      )
    )
  end)

  describe(
    'processing message',
    helpers.clean_buffer('#eval IO.sleep 5000', function()
      it('is shown while a file is processing', function()
        local result = vim.wait(10000, function()
          return require('lean.progress').percentage() < 100
        end)
        assert.message('file was never processing').is_true(result)
        assert.infoview_contents_nowait.are 'Processing file...'
      end)
    end)
  )
end)
