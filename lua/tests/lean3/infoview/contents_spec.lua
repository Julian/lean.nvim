local clean_buffer = require('tests.lean3.helpers').clean_buffer
local fixtures = require 'tests.lean3.fixtures'
local helpers = require 'tests.helpers'
local infoview = require 'lean.infoview'

require('lean').setup { infoview = { use_widgets = false } }

helpers.if_has_lean3('components', function()
  vim.cmd('edit! ' .. fixtures.project.path .. '/src/bar/baz.lean')

  it('shows a term goal', function()
    helpers.move_cursor { to = { 3, 27 } }

    assert.infoview_contents.are [[
      ▶ 1 goal
      ⊢ ℕ
    ]]
  end)

  it('shows a tactic goal', function()
    helpers.move_cursor { to = { 6, 0 } }
    assert.infoview_contents.are [[
      ▶ 1 goal
      p q : Prop
      ⊢ p ∨ q → q ∨ p
    ]]
  end)

  it('shows multiple goals', function()
    helpers.move_cursor { to = { 20, 2 } }
    assert.infoview_contents.are [[
      ▶ 2 goals
      case nat.zero
      ⊢ 0 = 0
      case nat.succ
      n : ℕ
      ⊢ n.succ = n.succ
    ]]
  end)

  if vim.version().major >= 1 or vim.version().minor >= 6 then
    it('properly handles multibyte characters', function()
      helpers.move_cursor { to = { 24, 61 } }
      assert.infoview_contents.are [[
        ▶ 1 goal
        𝔽 : Type
        ⊢ 𝔽 = 𝔽
      ]]

      -- NOTE: spurious (checks for a zero-length Lean 3 response,
      -- which could have multiple causes)
      helpers.move_cursor { to = { 24, 58 } }
      helpers.wait_for_loading_pins()
      assert.infoview_contents_nowait.are [[
      ]]

      helpers.move_cursor { to = { 24, 60 } }
      assert.infoview_contents.are [[
        ▶ 1 goal
        𝔽 : Type
        ⊢ 𝔽 = 𝔽
      ]]
    end)
  end

  describe(
    'cursor position',
    clean_buffer(function()
      it('is set to the goal line', function()
        local lines = { 'example ' }
        for i = 1, 100 do
          table.insert(lines, '(h' .. i .. ' : ' .. i .. ' = ' .. i .. ')')
        end
        table.insert(lines, ': true :=')
        table.insert(lines, 'sorry')

        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        helpers.move_cursor { to = { #lines, 1 } }
        helpers.wait_for_loading_pins()

        vim.api.nvim_set_current_win(infoview.get_current_infoview().window)

        assert.current_line.is '⊢ true'
        assert.are.equal(vim.api.nvim_win_get_cursor(0)[2], #'⊢ ')
      end)
    end)
  )
end)
