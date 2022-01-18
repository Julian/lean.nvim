require('tests.helpers')
local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('lean').setup{}

describe('Infoview.toggle', function()

  local lean_window

  it('closes an open infoview', function()
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    vim.cmd('edit! ' .. fixtures.lean3_project.some_existing_file)
    lean_window = vim.api.nvim_get_current_win()
    local current_infoview = infoview.get_current_infoview()

    assert.are.same_elements(
      { lean_window, current_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    current_infoview:toggle()
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))
  end)

  it('opens a closed infoview', function()
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))
    local current_infoview = infoview.get_current_infoview()
    current_infoview:toggle()
    assert.are.same_elements(
      { lean_window, current_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )
  end)

  it('reopens when an infoview has been reused for editing a file', function()
    vim.cmd('tabnew')
    local transient_window = vim.api.nvim_get_current_win()

    vim.cmd('edit! ' .. fixtures.lean_project.some_existing_file)
    local initial_infoview = infoview.get_current_infoview()
    local initial_infoview_window = initial_infoview.window
    assert.are.same_elements(
      { transient_window, initial_infoview_window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    vim.cmd(':quit')
    assert.is.equal(initial_infoview_window, vim.api.nvim_get_current_win())
    vim.cmd('edit! ' .. fixtures.lean_project.some_existing_file)
    assert.are.same({ initial_infoview_window }, vim.api.nvim_tabpage_list_wins(0))

    local second_infoview = infoview.get_current_infoview()
    assert.is_not.equal(second_infoview.window, initial_infoview_window)
    second_infoview:toggle()
    assert.are.same_elements(
      { initial_infoview_window, second_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    vim.cmd('tabclose')
  end)

  it('toggles back and forth', function()
    local current_infoview = infoview.get_current_infoview()
    assert.are.same_elements(
      { lean_window, current_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    current_infoview:toggle()
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))

    current_infoview:toggle()
    assert.are.same_elements(
      { lean_window, current_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    current_infoview:toggle()
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))
  end)
end)
