---@brief [[
--- Tests for basic Lean language support.
---@brief ]]

local dedent = require('lean._util').dedent
local helpers = require('tests.helpers')

require('lean').setup{}

for _, ft in pairs({"lean3", "lean"}) do
describe(ft .. ' commenting', function()
  it('comments out single lines', helpers.clean_buffer(ft, 'def best := 37', function()
    vim.cmd('TComment')
    assert.contents.are('-- def best := 37')
  end))

  it('comments out multiple lines inline by default', helpers.clean_buffer(ft, [[
def foo := 12
def bar := 37]], function()
    vim.cmd(':% TComment')
    assert.contents.are(dedent[[
      -- def foo := 12
      -- def bar := 37
    ]])
  end))

  it('can comment out block comments', helpers.clean_buffer(ft, [[
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
end
