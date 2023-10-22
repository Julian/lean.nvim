---@brief [[
--- Tests for basic Lean language support.
---@brief ]]

local clean_buffer = require('tests.lean3.helpers').clean_buffer
local dedent = require('lean._util').dedent
local helpers = require('tests.helpers')

require('lean').setup{}

helpers.if_has_lean3('commenting', function()
  it('comments out single lines', clean_buffer('def best := 37', function()
    vim.cmd.TComment()
    assert.contents.are('-- def best := 37')
  end))

  it('comments out multiple lines inline by default', clean_buffer([[
def foo := 12
def bar := 37]], function()
    vim.cmd(':% TComment')
    assert.contents.are(dedent[[
      -- def foo := 12
      -- def bar := 37
    ]])
  end))

  it('can comment out block comments', clean_buffer([[
def foo := 12
def bar := 37]], function()
    vim.cmd(':% TCommentBlock')
    assert.contents.are(dedent[[
      /-
      def foo := 12
      def bar := 37
      -/
    ]])
  end))
end)
