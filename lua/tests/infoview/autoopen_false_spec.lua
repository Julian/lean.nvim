require('tests.helpers')
local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('lean').setup{ infoview = { autoopen = false } }

describe('infoview', function()

  local lean_window

  it('does not automatically open infoviews', function(_)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    vim.cmd('edit! ' .. fixtures.lean3_project.some_existing_file)
    lean_window = vim.api.nvim_get_current_win()
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))
  end)

  it('allows infoviews to be manually opened', function(_)
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))
    infoview.get_current_infoview():open()
    assert.are.same_elements(
      { lean_window, infoview.get_current_infoview().window },
      vim.api.nvim_tabpage_list_wins(0)
    )
  end)
end)
