---@brief [[
--- Tests for the infoview when interactive widgets are enabled.
---
--- A tip for debugging failures is that until we have generic retrying for
--- making RPC calls, a test can fail here somewhere but *succeed* if you make
--- it be the only test in some scratch file (where then it likely becomes the
--- only RPC request we make). If you find this happens, it signals we're
--- missing some retry logic for the RPC call being made.
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

          ▶ expected type (2:17-2:19)
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
        helpers.move_cursor { to = { 2, 9 } }
        assert.infoview_contents.are [[
          ▶ 2 goals
          case zero
          ⊢ 0 = 0

          case succ
          n✝ : Nat
          ⊢ n✝ + 1 = n✝ + 1

          ▶ expected type (2:9-2:10)
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
          elab "#infoMessage" : command => Lean.logInfo "Hello"
          #infoMessage
        ]],
        function()
          helpers.move_cursor { to = { 3, 2 } }
          assert.infoview_contents.are [[
            ▶ 3:1-3:13: information:
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
          elab "#warningMessage" : command => Lean.logWarning "Hmm..."
          #warningMessage
        ]],
        function()
          helpers.move_cursor { to = { 3, 2 } }
          assert.infoview_contents.are [[
            ▶ 3:1-3:16: warning:
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
          elab "#errorMessage" : command => Lean.logError "Uh oh!"
          #errorMessage
        ]],
        function()
          helpers.move_cursor { to = { 3, 2 } }
          assert.infoview_contents.are [[
            ▶ 3:1-3:14: error:
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
          elab "#multilineNoNewline" : command => do
            Lean.logInfo "Multiple\nLine\nMessage"
            Lean.logInfo "Another"
          #multilineNoNewline
        ]],
        function()
          helpers.move_cursor { to = { 5, 2 } }
          assert.infoview_contents.are [[
            ▶ 5:1-5:20: information:
            Multiple
            Line
            Message

            ▶ 5:1-5:20: information:
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
          elab "#multilineWithNewline" : command => do
            Lean.logInfo "Multiple\nLines\n"
            Lean.logInfo "Another"
          #multilineWithNewline
        ]],
        function()
          helpers.move_cursor { to = { 5, 2 } }
          assert.infoview_contents.are [[
            ▶ 5:1-5:22: information:
            Multiple
            Lines


            ▶ 5:1-5:22: information:
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
          elab "#multipleMessages" : command => do
            Lean.logInfo "So"
            Lean.logWarning "Many..."
            Lean.logError "Messages!"
          #multipleMessages
        ]],
        function()
          helpers.move_cursor { to = { 6, 1 } }
          assert.infoview_contents.are [[
            ▶ 6:1-6:18: information:
            So

            ▶ 6:1-6:18: warning:
            Many...

            ▶ 6:1-6:18: error:
            Messages!
          ]]
        end
      )
    )

    it(
      'shows known widget instance diagnostics',
      helpers.clean_buffer(
        [[
          import Lean

          open Lean

          @[widget_module]
          def TestingModule : Widget.Module where
            javascript := "
              import * as React from 'react'
              export default function(props) { return React.createElement('h1', {}, props[0]) }
            "

          elab "#knownWidget" : command => do
            let widget : MessageData := .ofWidget {
              id := `leanNvimTestWidget
              javascriptHash := TestingModule.javascriptHash
              props := Server.RpcEncodable.rpcEncode ["veryImportantStuff"]
            } "This will be in the hover."
            logInfo widget

          #knownWidget
        ]],
        function()
          require('lean.widgets').implement('leanNvimTestWidget', function(_, props)
            return require('lean.tui').Element:new { text = props[1] }
          end)

          helpers.move_cursor { to = { 20, 2 } }
          assert.infoview_contents.are [[
            ▶ 20:1-20:13: information:
            veryImportantStuff
          ]]
        end
      )
    )

    it(
      'shows alternate text for unknown widget instance diagnostics',
      helpers.clean_buffer(
        [[
          import Lean

          open Lean

          elab "#unknownWidget" : command => do
            let widget : MessageData := .ofWidget {
              id := `someUnknownWidget
              javascriptHash := 0
              props := Server.RpcEncodable.rpcEncode "veryImportantProp"
            } "You're gonna see this alternate text."
            logInfo widget

          #unknownWidget
        ]],
        function()
          helpers.move_cursor { to = { 13, 2 } }
          assert.infoview_contents.are [[
            ▶ 13:1-13:15: information:
            You're gonna see this alternate text.
          ]]
        end
      )
    )

    it(
      'shows diagnostics for files with immediate diagnostics',
      helpers.clean_buffer('import DoesNotExist', function()
        -- FIXME: This is a bug in `wait_for_loading_pins` (which is already
        -- something isn't waiting properly, and nondeterministically we don't
        -- end up with the right contents in tests :/
        helpers.wait_for_loading_pins()
        vim.wait(10000, function()
          return require('lean.infoview').get_current_infoview():get_line(1) ~= nil
        end)
        -- the output in this case has the search path in it, so just match a
        -- bit of our expected contents
        assert.are.same(
          [[unknown module prefix 'DoesNotExist']],
          require('lean.infoview').get_current_infoview():get_line(1)
        )
      end)
    )

    it(
      'shows diagnostics for files with broken syntax',
      helpers.clean_buffer('import 37', function()
        -- FIXME: This is a bug in `wait_for_loading_pins` (which is already
        -- called by `assert.infoview_contents`) -- something isn't waiting
        -- properly, and nondeterministically we don't end up with the right
        -- contents in tests :/
        helpers.wait_for_loading_pins()
        vim.wait(10000, function()
          return not vim.deep_equal(
            require('lean.infoview').get_current_infoview():get_lines(),
            { '' }
          )
        end)
        assert.infoview_contents.are [[
            ▶ 1:7-1:10: error:
            unexpected token; expected identifier
          ]]
      end)
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

  describe(
    'language server dead',
    helpers.clean_buffer([[#check 37]], function()
      it('is shown when the server is dead', function()
        helpers.wait_for_ready_lsp()
        vim.lsp.stop_client(vim.lsp.get_clients())
        local succeeded = vim.wait(1000, function()
          return vim.tbl_isempty(vim.lsp.get_clients())
        end)
        assert.message("Couldn't kill the LSP!").is_true(succeeded)

        -- We don't immediately mark the infoview with our dead message.
        -- In theory maybe we could by attaching to `LspDetach` and triggering
        -- a final update, but for now this seems OK.
        helpers.move_cursor { to = { 1, 6 } }
        assert.infoview_contents.are '🪦 The Lean language server is dead.'
      end)
    end)
  )
end)
