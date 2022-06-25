---@brief [[
--- Tests for repositioning infoviews (when e.g. screen dimensions change).
---@brief ]]

require('tests.helpers')
local infoview = require('lean.infoview')

local WIDTH = 20
local HEIGHT = 10

require('lean').setup{
  infoview = { autoopen = false, width = WIDTH, height = HEIGHT },
}

describe('infoview window', function()

  local lean_window = vim.api.nvim_get_current_win()

  it('moves to vertical when the screen dimensions become landscape', function(_)
    vim.o.columns = 24
    vim.o.lines = 80
    local current_infoview = infoview.open()
    assert.are.same(
      { 'col', { { 'leaf', lean_window }, { 'leaf', current_infoview.window } } },
      vim.fn.winlayout()
    )
    assert.are.same(
      vim.api.nvim_win_get_height(infoview.get_current_infoview().window),
      HEIGHT
    )
    vim.o.columns = 80
    vim.o.lines = 24

    infoview.reposition()

    assert.are.same(
      { 'row', { { 'leaf', lean_window }, { 'leaf', current_infoview.window } } },
      vim.fn.winlayout()
    )
    assert.are.same(
      vim.api.nvim_win_get_width(infoview.get_current_infoview().window),
      WIDTH
    )

    infoview.close()
  end)

  it('does not touch a landscape layout if it is already oriented correctly', function(_)
    vim.o.columns = 24
    vim.o.lines = 80
    local current_infoview = infoview.open()
    vim.cmd[[wincmd L]]
    assert.are.same(
      { 'row', { { 'leaf', current_infoview.window }, { 'leaf', lean_window } } },
      vim.fn.winlayout()
    )
    vim.o.columns = 80
    vim.o.lines = 24

    infoview.reposition()

    assert.are.same(
      { 'row', { { 'leaf', current_infoview.window }, { 'leaf', lean_window } } },
      vim.fn.winlayout()
    )

    infoview.close()
  end)

  it('moves to horizontal when the screen dimensions become portrait', function(_)
    vim.o.columns = 80
    vim.o.lines = 24
    local current_infoview = infoview.open()
    assert.are.same(
      { 'row', { { 'leaf', lean_window }, { 'leaf', current_infoview.window } } },
      vim.fn.winlayout()
    )
    assert.are.same(
      vim.api.nvim_win_get_width(infoview.get_current_infoview().window),
      WIDTH
    )
    vim.o.columns = 24
    vim.o.lines = 80

    infoview.reposition()

    assert.are.same(
      { 'col', { { 'leaf', lean_window }, { 'leaf', current_infoview.window } } },
      vim.fn.winlayout()
    )
    assert.are.same(
      vim.api.nvim_win_get_height(infoview.get_current_infoview().window),
      HEIGHT
    )

    infoview.close()
  end)

  it('does not touch a portrait layout if it is already oriented correctly', function(_)
    vim.o.columns = 80
    vim.o.lines = 24
    local current_infoview = infoview.open()
    vim.cmd[[wincmd K]]
    assert.are.same(
      { 'col', { { 'leaf', lean_window }, { 'leaf', current_infoview.window } } },
      vim.fn.winlayout()
    )
    vim.o.columns = 24
    vim.o.lines = 80

    infoview.reposition()

    assert.are.same(
      { 'col', { { 'leaf', lean_window }, { 'leaf', current_infoview.window } } },
      vim.fn.winlayout()
    )

    infoview.close()
  end)

  it('does not touch layouts with more than two windows', function(_)
    vim.o.columns = 80
    vim.o.lines = 24

    infoview.open()
    vim.cmd[[split]]

    local layout = vim.fn.winlayout()

    infoview.reposition()
    assert.are.same(layout, vim.fn.winlayout())

    vim.o.columns = 24
    vim.o.lines = 80

    infoview.reposition()
    assert.are.same(layout, vim.fn.winlayout())

    vim.o.columns = 24
    vim.o.lines = 80

    vim.o.columns = 80
    vim.o.lines = 24

    infoview.reposition()
    assert.are.same(layout, vim.fn.winlayout())

    infoview.close()
  end)

  it('does not touch leaf windows', function(_)
    vim.cmd[[wincmd o]]
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    local layout = vim.fn.winlayout()
    infoview.reposition()
    assert.are.same(layout, vim.fn.winlayout())
  end)
end)
