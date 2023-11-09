---@brief [[
--- Tests for commenting, currently (only) via TComment.
---@brief ]]

local helpers = require('tests.helpers')

require('lean').setup{}

describe('commenting', function()
  it('comments out single lines', helpers.clean_buffer('def best := 37', function()
    vim.cmd.TComment()
    assert.contents.are('-- def best := 37')
  end))

  it('comments out multiple lines inline by default', helpers.clean_buffer([[
    def foo := 12
    def bar := 37
  ]], function()
    vim.cmd(':% TComment')
    assert.contents.are[[
      -- def foo := 12
      -- def bar := 37
    ]]
  end))

  it('can comment out block comments', helpers.clean_buffer([[
    def foo := 12
    def bar := 37
  ]], function()
    vim.cmd(':% TCommentBlock')
    assert.contents.are[[
      /-
      def foo := 12
      def bar := 37
      -/
    ]]
  end))
end)
