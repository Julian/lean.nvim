---@brief [[
--- Tests for the placing of infoview pins.
---@brief ]]
local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup { lsp = { enable = true } }

describe(
  'infoview pins',
  helpers.clean_buffer(
    [[
      theorem has_tactic_goal : p ∨ q → q ∨ p := by
        intro h
        cases h with
        | inl h1 =>
          apply Or.inr
          exact h1
        | inr h2 =>
          apply Or.inl
          assumption
    ]],
    function()
      local first_pin_position

      it('can be placed', function()
        local filename = vim.api.nvim_buf_get_name(0)

        first_pin_position = { 7, 5 }
        helpers.move_cursor { to = first_pin_position }
        assert.infoview_contents.are [[
          case inr
          p q : Prop
          h2 : q
          ⊢ q ∨ p

          ▶ expected type (7:3-7:6)
          ⊢ ∀ {a b : Prop}, b → a ∨ b
        ]]

        infoview.add_pin()
        -- FIXME: The pin add temporarily clears the infoview (until an update).
        --        Maybe it shouldn't and should just be appending itself to the
        --        existing contents (in which case an immediate assertion here
        --        should be added).
        helpers.move_cursor { to = { 4, 5 } }
        assert.infoview_contents.are(string.format(
          [[
            case inl
            p q : Prop
            h1 : p
            ⊢ q ∨ p

            ▶ expected type (4:3-4:6)
            ⊢ ∀ {a b : Prop}, a → a ∨ b

            -- %s at 7:6
            case inr
            p q : Prop
            h2 : q
            ⊢ q ∨ p

            ▶ expected type (7:3-7:6)
            ⊢ ∀ {a b : Prop}, b → a ∨ b
          ]],
          filename
        ))

        helpers.move_cursor { to = { 1, 49 } }
        infoview.add_pin()

        helpers.move_cursor { to = { 5, 4 } }
        assert.infoview_contents.are(string.format(
          [[
            case inl.h
            p q : Prop
            h1 : p
            ⊢ p

            -- %s at 7:6
            case inr
            p q : Prop
            h2 : q
            ⊢ q ∨ p

            ▶ expected type (7:3-7:6)
            ⊢ ∀ {a b : Prop}, b → a ∨ b

            -- %s at 1:50
            p q : Prop
            ⊢ p ∨ q → q ∨ p
          ]],
          filename,
          filename
        ))

        assert.is.equal(2, #infoview.get_current_infoview().info.pins)
      end)

      it('shows pin locations via extmarks', function()
        assert.is_not.equal(0, #infoview.get_current_infoview().info.pins)
        local before_pin = { first_pin_position[1] - 1, 0 }
        local after_pin = { first_pin_position[1] + 1, 0 }
        -- Something here is changing in nvim 0.10 apparently, who knows if intentionally -- hence the filter.
        local extmarks = vim.tbl_filter(function(mark)
          return mark[4].virt_text ~= nil
        end, helpers.all_lean_extmarks(0, before_pin, after_pin))
        assert.is.equal(1, #extmarks)
        local details = extmarks[1][4]
        assert.is.equal('← 1', details.virt_text[1][1])
      end)

      it('can be cleared', function()
        assert.is_true(#infoview.get_current_infoview().info.pins > 0)

        infoview.clear_pins()
        assert.infoview_contents.are [[
          case inl.h
          p q : Prop
          h1 : p
          ⊢ p
        ]]

        -- Still shows the right contents after a final movement / update
        helpers.move_cursor { to = { 7, 5 } }
        assert.infoview_contents.are [[
          case inr
          p q : Prop
          h2 : q
          ⊢ q ∨ p

          ▶ expected type (7:3-7:6)
          ⊢ ∀ {a b : Prop}, b → a ∨ b
        ]]

        assert.is.equal(0, #infoview.get_current_infoview().info.pins)
      end)

      -- FIXME: This seems to fail with errors saying it's misusing vim.schedule.
      pending('can be re-placed after being cleared', function()
        helpers.move_cursor { to = { 4, 5 } }
        infoview.add_pin()
        infoview.clear_pins()
        infoview.add_pin()
        assert.infoview_contents.are(string.format(
          [[
            case inl
            p q : Prop
            h1 : p
            ⊢ q ∨ p

            -- %s at 4:6
            case inl
            p q : Prop
            h1 : p
            ⊢ q ∨ p
          ]],
          vim.api.nvim_buf_get_name(0)
        ))
      end)

      describe(
        'edits around pin',
        helpers.clean_buffer(
          [[
            theorem has_tactic_goal : p ∨ q → q ∨ p := by
              intro h
              cases h with
              | inl h1 =>
                apply Or.inr
                exact h1
              | inr h2 =>
                apply Or.inl
                assumption
          ]],
          function()
            infoview.clear_pins()
            helpers.move_cursor { to = { 4, 12 } }
            infoview.add_pin()

            it('moves pin when lines are added above it', function()
              vim.api.nvim_buf_set_lines(0, 0, 0, true, { 'theorem foo : 2 = 2 := rfl', '' })
              helpers.move_cursor { to = { 1, 24 } }
              assert.infoview_contents.are(string.format(
                [[
                  ▶ expected type (1:24-1:27)
                  ⊢ 2 = 2

                  -- %s at 6:11
                  case inl
                  p q : Prop
                  h1 : p
                  ⊢ q ∨ p
                ]],
                vim.api.nvim_buf_get_name(0)
              ))
            end)

            it('moves pin when lines are removed above it', function()
              assert.infoview_contents.are(string.format(
                [[
                  ▶ expected type (1:24-1:27)
                  ⊢ 2 = 2

                  -- %s at 6:11
                  case inl
                  p q : Prop
                  h1 : p
                  ⊢ q ∨ p
                ]],
                vim.api.nvim_buf_get_name(0)
              ))

              helpers.move_cursor { to = { 3, 50 } }
              vim.api.nvim_buf_set_lines(0, 0, 2, true, {})

              assert.infoview_contents.are(string.format(
                [[
                  p q : Prop
                  ⊢ p ∨ q → q ∨ p

                  -- %s at 4:11
                  case inl
                  p q : Prop
                  h1 : p
                  ⊢ q ∨ p
                ]],
                vim.api.nvim_buf_get_name(0)
              ))
            end)

            it('does not move pin when lines are added or removed below it', function()
              assert.infoview_contents.are(string.format(
                [[
                  p q : Prop
                  ⊢ p ∨ q → q ∨ p

                  -- %s at 4:11
                  case inl
                  p q : Prop
                  h1 : p
                  ⊢ q ∨ p
                ]],
                vim.api.nvim_buf_get_name(0)
              ))

              vim.api.nvim_buf_set_lines(0, -1, -1, true, { '', 'theorem foo : 2 = 2 := rfl' })

              helpers.move_cursor { to = { 11, 24 } }
              assert.infoview_contents.are(string.format(
                [[
                  ▶ expected type (11:24-11:27)
                  ⊢ 2 = 2

                  -- %s at 4:11
                  case inl
                  p q : Prop
                  h1 : p
                  ⊢ q ∨ p
                ]],
                vim.api.nvim_buf_get_name(0)
              ))

              vim.api.nvim_buf_set_lines(0, 9, 11, true, {})

              helpers.move_cursor { to = { 1, 50 } }
              assert.infoview_contents.are(string.format(
                [[
                  p q : Prop
                  ⊢ p ∨ q → q ∨ p

                  -- %s at 4:11
                  case inl
                  p q : Prop
                  h1 : p
                  ⊢ q ∨ p
                ]],
                vim.api.nvim_buf_get_name(0)
              ))
            end)

            it('moves pin when changes are made on its line before its column', function()
              helpers.move_cursor { to = { 4, 7 } }
              vim.cmd.normal 'cl37' -- h1 -> h37
              helpers.move_cursor { to = { 1, 50 } }
              assert.infoview_contents.are(string.format(
                [[
                  p q : Prop
                  ⊢ p ∨ q → q ∨ p

                  -- %s at 4:12
                  case inl
                  p q : Prop
                  h37 : p
                  ⊢ q ∨ p
                ]],
                vim.api.nvim_buf_get_name(0)
              ))
            end)

            it('does not move pin when changes are made on its line after its column', function()
              helpers.move_cursor { to = { 4, 13 } }
              vim.cmd.normal 'a    '
              helpers.move_cursor { to = { 1, 50 } }
              assert.infoview_contents.are(string.format(
                [[
                  p q : Prop
                  ⊢ p ∨ q → q ∨ p

                  -- %s at 4:12
                  case inl
                  p q : Prop
                  h37 : p
                  ⊢ q ∨ p
                ]],
                vim.api.nvim_buf_get_name(0)
              ))

              infoview.clear_pins()
              assert.infoview_contents.are [[
                p q : Prop
                ⊢ p ∨ q → q ∨ p
              ]]
            end)
          end
        )
      )

      describe('diff pins', function()
        local lean_window

        it('opens a diff window when placed', function()
          lean_window = vim.api.nvim_get_current_win()
          local current_infoview = infoview.get_current_infoview()
          assert.windows.are(lean_window, current_infoview.window)

          helpers.move_cursor { to = { 4, 5 } }
          infoview.set_diff_pin()

          assert.infoview_contents.are [[
            case inl
            p q : Prop
            h37 : p
            ⊢ q ∨ p

            ▶ expected type (4:3-4:6)
            ⊢ ∀ {a b : Prop}, a → a ∨ b
          ]]

          assert.diff_contents.are [[
            case inl
            p q : Prop
            h37 : p
            ⊢ q ∨ p

            ▶ expected type (4:3-4:6)
            ⊢ ∀ {a b : Prop}, a → a ∨ b
          ]]

          local diff_window = helpers.wait_for_new_window { lean_window, current_infoview.window }

          assert.windows.are(lean_window, current_infoview.window, diff_window)

          assert.is_true(vim.wo[current_infoview.window].diff)
          assert.is_true(vim.wo[diff_window].diff)
        end)

        it('maintains separate text', function()
          helpers.move_cursor { to = { 5, 5 } }

          assert.infoview_contents.are [[
            case inl.h
            p q : Prop
            h37 : p
            ⊢ p
          ]]

          assert.diff_contents.are [[
            case inl
            p q : Prop
            h37 : p
            ⊢ q ∨ p

            ▶ expected type (4:3-4:6)
            ⊢ ∀ {a b : Prop}, a → a ∨ b
          ]]
        end)

        it('closes the diff window if the infoview is closed', function()
          assert.is.equal(3, #vim.api.nvim_tabpage_list_wins(0))
          infoview.close()
          assert.windows.are(lean_window)
        end)

        it('reopens a diff window when the infoview is reopened', function()
          assert.windows.are(lean_window)

          local current_infoview = infoview.open()
          local diff_window = helpers.wait_for_new_window { lean_window, current_infoview.window }

          assert.windows.are(lean_window, current_infoview.window, diff_window)

          assert.is_true(vim.wo[current_infoview.window].diff)
          assert.is_true(vim.wo[diff_window].diff)
        end)

        it('closes when cleared', function()
          assert.is.equal(3, #vim.api.nvim_tabpage_list_wins(0))
          infoview.clear_diff_pin()
          assert.windows.are(lean_window, infoview.get_current_infoview().window)
        end)

        it('can be re-placed', function()
          assert.is.equal(2, #vim.api.nvim_tabpage_list_wins(0))
          helpers.move_cursor { to = { 3, 2 } }
          infoview.set_diff_pin()
          assert.is.equal(3, #vim.api.nvim_tabpage_list_wins(0))
        end)

        it('can be :quit', function()
          assert.is.equal(3, #vim.api.nvim_tabpage_list_wins(0))
          local current_infoview = infoview.get_current_infoview()
          local diff_window = helpers.wait_for_new_window { lean_window, current_infoview.window }
          vim.api.nvim_set_current_win(diff_window)
          vim.cmd.quit()
          assert.windows.are(lean_window, infoview.get_current_infoview().window)
        end)
      end)
    end
  )
)
