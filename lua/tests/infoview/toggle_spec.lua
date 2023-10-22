require('tests.helpers')
local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('lean').setup{}

describe('Infoview.toggle', function()

  local lean_window

  it('closes an open infoview', function()
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    vim.cmd('edit! ' .. fixtures.project.some_existing_file)
    lean_window = vim.api.nvim_get_current_win()
    local current_infoview = infoview.get_current_infoview()

    assert.windows.are(lean_window, current_infoview.window)

    current_infoview:toggle()
    assert.windows.are(lean_window)
  end)

  it('opens a closed infoview', function()
    assert.windows.are(lean_window)
    local current_infoview = infoview.get_current_infoview()
    current_infoview:toggle()
    assert.windows.are(lean_window, current_infoview.window)
  end)

  it('toggles back and forth', function()
    local current_infoview = infoview.get_current_infoview()
    assert.windows.are(lean_window, current_infoview.window)

    current_infoview:toggle()
    assert.windows.are(lean_window)

    current_infoview:toggle()
    assert.windows.are(lean_window, current_infoview.window)

    current_infoview:toggle()
    assert.windows.are(lean_window)
  end)
end)
