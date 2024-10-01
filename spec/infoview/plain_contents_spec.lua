---@brief [[
--- Tests for the infoview when interactive widgets are not enabled.
---@brief ]]

local fixtures = require 'spec.fixtures'
local helpers = require 'spec.helpers'

require('lean').setup { infoview = { use_widgets = false } }

describe('plain infoviews', function()
  describe('goals', function()
    vim.cmd.edit { fixtures.project.child 'Test.lean', bang = true }

    it('shows a term goal', function()
      helpers.move_cursor { to = { 3, 27 } }
      assert.infoview_contents.are [[
        ▶ expected type (3:28-3:36)
        ⊢ Nat
      ]]
    end)

    it('shows a tactic goal', function()
      helpers.move_cursor { to = { 6, 0 } }
      assert.infoview_contents.are [[
        p q : Prop
        ⊢ p ∨ q → q ∨ p
      ]]
    end)

    it('shows mixed goals', function()
      helpers.move_cursor { to = { 9, 11 } }
      assert.infoview_contents.are [[
        case inl.h
        p q : Prop
        h1 : p
        ⊢ p

        ▶ expected type (9:11-9:17)
        p q : Prop
        h1 : p
        ⊢ ∀ {a b : Prop}, b → a ∨ b
      ]]
    end)

    it('shows multiple goals', function()
      helpers.move_cursor { to = { 16, 2 } }
      assert.infoview_contents.are [[
        ▶ 2 goals
        case zero
        ⊢ 0 = 0

        case succ
        n✝ : Nat
        ⊢ n✝ + 1 = n✝ + 1
      ]]
    end)

    it('properly handles multibyte characters', function()
      helpers.move_cursor { to = { 20, 62 } }
      assert.infoview_contents.are [[
        ▶ expected type (20:54-20:57)
        𝔽 : Type
        ⊢ 𝔽 = 𝔽
      ]]

      helpers.move_cursor { to = { 20, 58 } }
      assert.infoview_contents.are [[
      ]]

      helpers.move_cursor { to = { 20, 60 } }
      assert.infoview_contents.are [[
        ▶ expected type (20:54-20:57)
        𝔽 : Type
        ⊢ 𝔽 = 𝔽
      ]]
    end)
  end)

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
