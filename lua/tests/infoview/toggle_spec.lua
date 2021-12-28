local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')
local helpers = require('tests.helpers')

helpers.setup {
  infoview = { autoopen = true },
}
describe('Infoview.toggle', function()

  local lean_window

  it('closes an open infoview', function()
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    helpers.edit_lean_buffer(fixtures.lean3_project.some_existing_file)
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

  pending('reopens when an infoview has been reused for editing a file', function()
    vim.cmd("tabnew")
    local tab2_window = vim.api.nvim_get_current_win()

    assert.are.same({ tab2_window }, vim.api.nvim_tabpage_list_wins(0))
    helpers.edit_lean_buffer(fixtures.lean3_project.some_existing_file)
    local tab2_infoview = infoview.get_current_infoview()
    local tab2_infoview_window = tab2_infoview.window
    assert.are.same_elements(
      { tab2_window, tab2_infoview_window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    vim.cmd(":quit")
    assert.are.same(vim.api.nvim_get_current_win(), tab2_infoview_window)
    helpers.edit_lean_buffer(fixtures.lean3_project.some_existing_file)
    assert.are.same({ tab2_infoview_window }, vim.api.nvim_tabpage_list_wins(0))

    local second_infoview = infoview.get_current_infoview()
    second_infoview:toggle()
    assert.are.same_elements(
      { tab2_infoview_window, second_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )
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
