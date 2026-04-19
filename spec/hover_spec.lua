---@brief [[
--- Tests for interactive hover popups.
---@brief ]]

local Window = require 'std.nvim.window'

local helpers = require 'spec.helpers'
local hover = require 'lean.hover'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe(
  'interactive hover',
  helpers.clean_buffer(
    [[
      #check Nat
      #check @Nat.add
    ]],
    function()
      local lean_window = Window:current()
      local current_infoview = infoview.get_current_infoview()

      -- Wait once for initial processing.
      helpers.move_cursor { to = { 1, 7 } }
      helpers.wait:for_processing()

      it('shows the signature, interactive type, documentation, and import', function()
        helpers.move_cursor { to = { 1, 7 } }

        local known_windows = { lean_window, current_infoview.window }

        hover()
        local hover_win = helpers.wait_for_new_window(known_windows)

        assert.contents.are {
          [[
            Nat : Type

            The natural numbers, starting at zero.

            This type is special-cased by both the kernel and the compiler, and overridden with an efficient
            implementation. Both use a fast arbitrary-precision arithmetic library (usually
            [GMP](https://gmplib.org/)); at runtime, `Nat` values that are sufficiently small are unboxed.

            ---
            *import Init.Prelude*
          ]],
          buffer = hover_win:buffer(),
        }

        hover_win:close()
        lean_window:make_current()
      end)

      it('shows a function type with its full signature', function()
        lean_window:make_current()
        helpers.move_cursor { to = { 2, 8 } }

        local known_windows = { lean_window, current_infoview.window }

        hover()
        local hover_win = helpers.wait_for_new_window(known_windows)

        assert.contents.are {
          [[
            Nat.add : Nat → Nat → Nat

            Addition of natural numbers, typically used via the `+` operator.

            This function is overridden in both the kernel and the compiler to efficiently evaluate using the
            arbitrary-precision arithmetic library. The definition provided here is the logical model.

            ---
            *import Init.Prelude*
          ]],
          buffer = hover_win:buffer(),
        }

        hover_win:close()
        lean_window:make_current()
      end)

      it('supports clicking on types within the hover', function()
        lean_window:make_current()
        helpers.move_cursor { to = { 1, 7 } }

        local known_windows = { lean_window, current_infoview.window }

        hover()
        local hover_win = helpers.wait_for_new_window(known_windows)

        local lines = hover_win:buffer():lines()
        assert.is.equal('Nat : Type', lines[1])

        -- Enter the hover window and move to the interactive 'Type' part.
        -- 'Nat : ' is 6 bytes, so 'Type' starts at column 6.
        vim.api.nvim_set_current_win(hover_win.id)
        helpers.move_cursor { to = { 1, 6 } }

        -- Click on 'Type' to see its type info.
        helpers.feed '<CR>'
        local with_hover = vim.list_extend(vim.deepcopy(known_windows), { hover_win })
        local tooltip = helpers.wait_for_new_window(with_hover)
        assert.contents.are {
          -- Trailing space is from the Lean server's formatting.
          'Type : Type 1\n\nA type universe. `Type ≡ Type 0`, `Type u ≡ Sort (u + 1)`. ',
          buffer = tooltip:buffer(),
        }

        -- Close the tooltip and hover.
        helpers.feed '<Esc>'
        hover_win:close()
        lean_window:make_current()
      end)

      it('falls back to standard hover when RPC fails', function()
        lean_window:make_current()
        helpers.move_cursor { to = { 1, 0 } }

        local known_windows = { lean_window, current_infoview.window }

        hover()
        local hover_win = helpers.wait_for_new_window(known_windows)

        -- Standard hover should still appear with some content.
        local lines = hover_win:buffer():lines()
        assert.is_true(#lines > 0)

        hover_win:close()
        lean_window:make_current()
      end)
    end
  )
)
