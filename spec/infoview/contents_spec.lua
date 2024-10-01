---@brief [[
--- Tests for the infoview when interactive widgets are enabled.
---@brief ]]

local fixtures = require 'spec.fixtures'
local helpers = require 'spec.helpers'

require('lean').setup {}

describe('interactive infoviews', function()
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
      helpers.move_cursor { to = { 16, 3 } }
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

  describe(
    'diagnostics',
    helpers.clean_buffer('example : 37 = 37 := by', function()
      it('are shown in the infoview', function()
        helpers.move_cursor { to = { 1, 19 } }
        assert.infoview_contents.are [[
          ▶ 1:22-1:24: error:
          unsolved goals
          ⊢ 37 = 37
        ]]
      end)
    end)
  )

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
