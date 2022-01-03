---@brief [[
--- Tests for the placing of infoview pins.
---@brief ]]
local dedent = require('lean._util').dedent
local infoview = require('lean.infoview')
local helpers = require('tests.helpers')

require('lean').setup{ lsp = { enable = true } }

describe('infoview pins', function()
  it('can be placed and cleared', helpers.clean_buffer('lean', dedent[[
    theorem has_tactic_goal : p ∨ q → q ∨ p := by
      intro h
      cases h with
      | inl h1 =>
        apply Or.inr
        exact h1
      | inr h2 =>
        apply Or.inl
        assumption
    ]], function()
    local filename = vim.api.nvim_buf_get_name(0)

    helpers.move_cursor{ to = {7, 5} }
    helpers.wait_for_infoview_contents('case inr')
    assert.infoview_contents.are[[
      ▶ 1 goal
      case inr
      p q : Prop
      h2 : q
      ⊢ q ∨ p
    ]]

    infoview.get_current_infoview().info:add_pin()
    -- FIXME: The pin add temporarily clears the infoview (until an update).
    --        Maybe it shouldn't and should just be appending itself to the
    --        existing contents (in which case an immediate assertion here
    --        should be added).
    helpers.move_cursor{ to = {4, 5} }
    helpers.wait_for_infoview_contents('case inl')
    assert.infoview_contents.are(string.format([[
      ▶ 1 goal
      case inl
      p q : Prop
      h1 : p
      ⊢ q ∨ p

      -- %s at 7:6
      ▶ 1 goal
      case inr
      p q : Prop
      h2 : q
      ⊢ q ∨ p
    ]], filename))

    helpers.move_cursor{ to = {1, 49} }
    infoview.get_current_infoview().info:add_pin()

    helpers.move_cursor{ to = {5, 4} }
    helpers.wait_for_infoview_contents('case inl.h')
    assert.infoview_contents.are(string.format([[
      ▶ 1 goal
      case inl.h
      p q : Prop
      h1 : p
      ⊢ p

      -- %s at 7:6
      ▶ 1 goal
      case inr
      p q : Prop
      h2 : q
      ⊢ q ∨ p

      -- %s at 1:50
      ▶ 1 goal
      p q : Prop
      ⊢ p ∨ q → q ∨ p
    ]], filename, filename))

    infoview.get_current_infoview().info:clear_pins()
    assert.infoview_contents.are[[
      ▶ 1 goal
      case inl.h
      p q : Prop
      h1 : p
      ⊢ p
    ]]

    -- Still shows the right contents after a final movement / update
    helpers.move_cursor{ to = {7, 5} }
    helpers.wait_for_infoview_contents('case inr')
    assert.infoview_contents.are[[
      ▶ 1 goal
      case inr
      p q : Prop
      h2 : q
      ⊢ q ∨ p
    ]]
  end))

  it('can be re-placed after being cleared', helpers.clean_buffer('lean', dedent[[
    theorem has_tactic_goal : p ∨ q → q ∨ p := by
      intro h
      cases h with
      | inl h1 =>
        apply Or.inr
        exact h1
      | inr h2 =>
        apply Or.inl
        assumption
    ]], function()
    helpers.move_cursor{ to = {4, 5} }
    infoview.get_current_infoview().info:add_pin()
    -- infoview.get_current_infoview().info:clear_pins()
    -- infoview.get_current_infoview().info:add_pin()
    helpers.wait_for_infoview_contents('case inl.*case inl')
    assert.infoview_contents.are(string.format([[
      ▶ 1 goal
      case inl
      p q : Prop
      h1 : p
      ⊢ q ∨ p

      -- %s at 4:6
      ▶ 1 goal
      case inl
      p q : Prop
      h1 : p
      ⊢ q ∨ p
    ]], vim.api.nvim_buf_get_name(0)))
  end))
end)
