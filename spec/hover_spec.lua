---@brief [[
--- Tests for interactive hover popups.
---@brief ]]

local Window = require 'std.nvim.window'

local helpers = require 'spec.helpers'
local hover = require 'lean.hover'
local infoview = require 'lean.infoview'

describe(
  'interactive hover',
  helpers.clean_buffer(
    [[
      #check Nat
      #check @Nat.add
      theorem mlt_521_repro {α : Type} {β : Type} (h_a : α = β) (h_b : β = α) (h_c : α = β) (h_d : β = α) :
          (∀ x : α, x = x) ∧ (∀ y : β, y = y) ∧ (∀ z : α, z = z) ∧ (∀ w : β, w = w) :=
        sorry
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

      it('applies Lean syntax highlighting to the signature/type', function()
        lean_window:make_current()
        helpers.move_cursor { to = { 1, 7 } }

        local known_windows = { lean_window, current_infoview.window }

        hover()
        local hover_win = helpers.wait_for_new_window(known_windows)

        local lines = hover_win:buffer():lines()
        assert.is.equal('Nat : Type', lines[1])
        local type_col = lines[1]:find 'Type'
        assert.is_not_nil(type_col)

        -- synstack queries the buffer in the current window, so enter the
        -- hover window before asking what's at the position.
        local prev_win = Window:current()
        hover_win:make_current()
        local stack = vim.fn.synstack(1, type_col)
        local names = vim.tbl_map(function(id)
          return vim.fn.synIDattr(id, 'name')
        end, stack)
        prev_win:make_current()

        assert
          .message(('expected leanSort in synstack, got %s'):format(vim.inspect(names)))
          .is_true(vim.tbl_contains(names, 'leanSort'))

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

      it('preserves multi-line signatures whose binders contain colons', function()
        lean_window:make_current()
        -- Hover on the theorem name in its declaration on line 3.
        helpers.move_cursor { to = { 3, 10 } }

        local ids = { lean_window.id, current_infoview.window.id }

        hover()
        -- Poll until the hover window actually contains our theorem signature;
        -- the interactive-hover RPC can take longer than the default 1s
        -- `wait_for_new_window` allows.
        local hover_win
        local ok = vim.wait(15000, function()
          hover_win = vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(function(w)
            if vim.tbl_contains(ids, w) then
              return false
            end
            local buf = vim.api.nvim_win_get_buf(w)
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            return table.concat(lines, '\n'):match 'mlt_521_repro' ~= nil
          end)
          return hover_win ~= nil
        end)
        assert.message('Interactive hover never rendered.').is_true(ok)
        hover_win = Window:from_id(hover_win)

        local contents = table.concat(hover_win:buffer():lines(), '\n')

        -- Regression for #521: the parser used to split the signature at a
        -- ` : ` inside a binder when Lean wrapped the signature so the
        -- top-level `:` sat at end-of-line.  The final binder `(h_d : β = α)`
        -- ended up rendered as `∀ (w : <conclusion type>` instead.
        assert.has_match('%(h_d : β = α%)', contents)
        assert.is_nil(
          contents:match '∀%s*%(w%s*:%s*∀',
          ('binder `w` was misparsed:\n%s'):format(contents)
        )

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
