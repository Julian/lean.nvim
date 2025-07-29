---@brief [[
--- Tests for repositioning infoviews (when e.g. screen dimensions change).
---@brief ]]

local Tab = require 'std.nvim.tab'

require 'spec.helpers'
local infoview = require 'lean.infoview'

local WIDTH = 20
local HEIGHT = 10

require('lean').setup {
  infoview = { autoopen = false, width = WIDTH, height = HEIGHT },
}

describe('infoview window', function()
  local lean_window = vim.api.nvim_get_current_win()

  it('moves to vertical when the screen dimensions become landscape', function()
    vim.o.columns = 24
    vim.o.lines = 80
    local current_infoview = infoview.open()
    assert.are.same(
      { 'col', { { 'leaf', lean_window }, { 'leaf', current_infoview.window.id } } },
      vim.fn.winlayout()
    )
    assert.are.same(infoview.get_current_infoview().window:height(), HEIGHT)
    vim.o.columns = 80
    vim.o.lines = 24

    infoview.reposition()

    assert.are.same(
      { 'row', { { 'leaf', lean_window }, { 'leaf', current_infoview.window.id } } },
      vim.fn.winlayout()
    )
    assert.are.same(infoview.get_current_infoview().window:width(), WIDTH)

    infoview.close()
  end)

  it('does not touch a landscape layout if it is already oriented correctly', function()
    vim.o.columns = 24
    vim.o.lines = 80
    local current_infoview = infoview.open()
    vim.cmd.wincmd 'L'
    assert.are.same(
      { 'row', { { 'leaf', current_infoview.window.id }, { 'leaf', lean_window } } },
      vim.fn.winlayout()
    )
    vim.o.columns = 80
    vim.o.lines = 24

    infoview.reposition()

    assert.are.same(
      { 'row', { { 'leaf', current_infoview.window.id }, { 'leaf', lean_window } } },
      vim.fn.winlayout()
    )

    infoview.close()
  end)

  it('moves to horizontal when the screen dimensions become portrait', function()
    vim.o.columns = 80
    vim.o.lines = 24
    local current_infoview = infoview.open()
    assert.are.same(
      { 'row', { { 'leaf', lean_window }, { 'leaf', current_infoview.window.id } } },
      vim.fn.winlayout()
    )
    assert.are.same(infoview.get_current_infoview().window:width(), WIDTH)
    vim.o.columns = 24
    vim.o.lines = 80

    infoview.reposition()

    assert.are.same(
      { 'col', { { 'leaf', lean_window }, { 'leaf', current_infoview.window.id } } },
      vim.fn.winlayout()
    )
    assert.are.same(infoview.get_current_infoview().window:height(), HEIGHT)

    infoview.close()
  end)

  it('does not touch a portrait layout if it is already oriented correctly', function()
    vim.o.columns = 80
    vim.o.lines = 24
    local current_infoview = infoview.open()
    vim.cmd.wincmd 'K'
    assert.are.same(
      { 'col', { { 'leaf', lean_window }, { 'leaf', current_infoview.window.id } } },
      vim.fn.winlayout()
    )
    vim.o.columns = 24
    vim.o.lines = 80

    infoview.reposition()

    assert.are.same(
      { 'col', { { 'leaf', lean_window }, { 'leaf', current_infoview.window.id } } },
      vim.fn.winlayout()
    )

    infoview.close()
  end)

  it('resizes windows without moving them when there are more than 2', function()
    vim.o.columns = 80
    vim.o.lines = 24

    infoview.open()
    vim.cmd.split()

    local layout = vim.fn.winlayout()

    infoview.reposition()
    assert.are.same(layout, vim.fn.winlayout())

    vim.o.columns = 24
    vim.o.lines = 80

    infoview.reposition()
    assert.are.same(layout, vim.fn.winlayout())

    vim.o.columns = 80
    vim.o.lines = 24

    infoview.reposition()
    assert.are.same(layout, vim.fn.winlayout())

    assert.are.same(infoview.get_current_infoview().window:width(), WIDTH)

    infoview.close()
  end)

  it('does not touch leaf windows', function()
    vim.cmd.wincmd 'o'
    assert.is.equal(1, #Tab:current():windows())
    local layout = vim.fn.winlayout()
    infoview.reposition()
    assert.are.same(layout, vim.fn.winlayout())
  end)
end)
