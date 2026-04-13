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

local infoview = require 'lean.infoview'

require('lean').setup { progress_bars = { enable = false } }

describe('interactive infoview', function()
  it(
    'shows goals accomplished on the first line of a solved goal',
    helpers.clean_buffer([[example : 37 = 37 := by rfl]], function()
      assert.infoview_contents_at({ 1, 26 }).are 'Goals accomplished 🎉'
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
        assert.infoview_contents_at('sorry').are '⊢ 37 = 37'
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
        assert.infoview_contents_at('sorry').are [[
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
        assert.infoview_contents_at('sorry').are [[
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
          · sorry
          · sorry
      ]],
      function()
        assert.infoview_contents_at('sorry').are [[
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
          · sorry
          · sorry
      ]],
      function()
        assert.infoview_contents_at({ 2, 3 }).are [[
          ▼ 2 goals
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
    'shows No goals after tactic proofs are finished',
    helpers.clean_buffer(
      [[
        example : 37 = 37 := by rfl

        example : 12 = 12 := rfl
      ]],
      function()
        assert.infoview_contents_at({ 2, 0 }).are 'No goals.'
      end
    )
  )

  it(
    'shows a term goal with no hypotheses',
    helpers.clean_buffer([[def n : Nat := 37]], function()
      assert.infoview_contents_at({ 1, 17 }).are [[
        ▼ expected type (1:16-1:18)
        ⊢ Nat
      ]]
    end)
  )

  it(
    'shows a term goal with one hypothesis',
    helpers.clean_buffer([[def n (x : Nat) : Nat := x]], function()
      assert.infoview_contents_at({ 1, 26 }).are [[
        ▼ expected type (1:26-1:27)
        x : Nat
        ⊢ Nat
      ]]
    end)
  )

  it(
    'shows a term goal with multiple hypotheses',
    helpers.clean_buffer([[def n (A : Type) (a : A) : A := a]], function()
      assert.infoview_contents_at({ 1, 33 }).are [[
          ▼ expected type (1:33-1:34)
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
          sorry
      ]],
      function()
        assert.infoview_contents_at({ 2, 18 }).are [[
          this : Nat
          ⊢ 37 = 37

          ▼ expected type (2:17-2:19)
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
          · sorry
          · sorry
      ]],
      function()
        assert.infoview_contents_at({ 2, 9 }).are [[
          ▼ 2 goals
          case zero
          ⊢ 0 = 0

          case succ
          n✝ : Nat
          ⊢ n✝ + 1 = n✝ + 1

          ▼ expected type (2:9-2:10)
          n : Nat
          ⊢ Nat
        ]]
      end
    )
  )

  it(
    'shows goals with multibyte characters',
    helpers.clean_buffer([[def multibyte {𝔽 : Type} : 𝔽 = 𝔽 := rfl]], function()
      assert.infoview_contents_at({ 1, 48 }).are [[
          ▼ expected type (1:40-1:43)
          𝔽 : Type
          ⊢ 𝔽 = 𝔽
        ]]

      assert.infoview_contents_at({ 1, 44 }).are [[
      ]]

      assert.infoview_contents_at({ 1, 46 }).are [[
        ▼ expected type (1:40-1:43)
        𝔽 : Type
        ⊢ 𝔽 = 𝔽
      ]]
    end)
  )

  it(
    'shows goals accomplished on lines with multiple declarations',
    helpers.clean_buffer([[example : 2 = 2 := rfl example : 3 = 3 := by]], function()
      assert.infoview_contents_at({ 1, 20 }).are [[
        Goals accomplished 🎉

        ▼ expected type (1:20-1:23)
        ⊢ 2 = 2

        ▼ 1:43-1:45: error:
        unsolved goals
        ⊢ 3 = 3
      ]]

      assert.infoview_contents_at({ 1, 43 }).are [[
        Goals accomplished 🎉

        ⊢ 3 = 3

        ▼ 1:43-1:45: error:
        unsolved goals
        ⊢ 3 = 3
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
          assert.infoview_contents_at('^#infoMessage').are [[
            ▼ 3:1-3:13: information:
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
          assert.infoview_contents_at('^#warningMessage').are [[
            ▼ 3:1-3:16: warning:
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
          assert.infoview_contents_at('^#errorMessage').are [[
            ▼ 3:1-3:14: error:
            Uh oh!
          ]]
        end
      )
    )

    it(
      'shows the full range',
      helpers.clean_buffer(
        [[
          example : 2 = 2 := by
            exact (
              rfl :
                37
                =
                37)
        ]],
        function()
          assert.infoview_contents_at('exact').are [[
            ⊢ 2 = 2

            ▼ 2:3-6:10: error:
            Type mismatch
              rfl
            has type
              37 = 37
            but is expected to have type
              2 = 2
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
          assert.infoview_contents_at('^#multilineNoNewline').are [[
            ▼ 5:1-5:20: information:
            Multiple
            Line
            Message

            ▼ 5:1-5:20: information:
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
          assert.infoview_contents_at('^#multilineWithNewline').are [[
            ▼ 5:1-5:22: information:
            Multiple
            Lines


            ▼ 5:1-5:22: information:
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
          assert.infoview_contents_at('^#multipleMessages').are [[
            ▼ 6:1-6:18: information:
            So

            ▼ 6:1-6:18: warning:
            Many...

            ▼ 6:1-6:18: error:
            Messages!
          ]]
        end
      )
    )

    describe('widgets', function()
      local original = package.path
      package.path = package.path .. ';' .. require('spec.fixtures').widgets .. '/?.lua'

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
                id := `showPropWithHover
                javascriptHash := TestingModule.javascriptHash
                props := Server.RpcEncodable.rpcEncode ["veryImportantStuff"]
              } "This will be in the hover."
              logInfo widget

            #knownWidget
          ]],
          function()
            assert.infoview_contents_at('^#knownWidget').are [[
              ▼ 20:1-20:13: information:
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
            assert.infoview_contents_at('^#unknownWidget').are [[
              ▼ 13:1-13:15: information:
              You're gonna see this alternate text.
            ]]
          end
        )
      )

      package.path = original
    end)

    it(
      'shows diagnostics for files with immediate diagnostics',
      helpers.clean_buffer('import DoesNotExist', function()
        -- FIXME: This is a bug in `wait_for_loading_pins` (which is already
        -- something isn't waiting properly, and nondeterministically we don't
        -- end up with the right contents in tests :/
        helpers.wait_for_loading_pins()
        vim.wait(10000, function()
          return infoview.get_current_infoview():get_line(1) ~= nil
        end)
        -- the output in this case has the search path in it, so just match a
        -- bit of our expected contents
        assert.are.same(
          [[unknown module prefix 'DoesNotExist']],
          infoview.get_current_infoview():get_line(1)
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
          return not vim.deep_equal(infoview.get_current_infoview():get_lines(), { '' })
        end)
        assert.infoview_contents.are [[
          ▼ 1:7-1:10: error:
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

  describe('contents_at', function()
    it(
      'returns an element synchronously',
      helpers.clean_buffer(
        [[
          example : 37 = 37 := by
            sorry
        ]],
        function()
          local element = infoview.contents_at { 2, 2 }
          assert.is.equal('⊢ 37 = 37', element:to_string())
        end
      )
    )

    it(
      'calls a callback asynchronously',
      helpers.clean_buffer(
        [[
          example : 37 = 37 := by
            sorry
        ]],
        function()
          local got
          infoview.contents_at({ 2, 2 }, {
            callback = function(element)
              got = element:to_string()
            end,
          })
          vim.wait(10000, function()
            return got ~= nil
          end)
          assert.is.equal('⊢ 37 = 37', got)
        end
      )
    )
  end)
end)
