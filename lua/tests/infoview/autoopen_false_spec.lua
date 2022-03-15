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
    assert.windows.are(lean_window)
  end)

  it('allows infoviews to be manually opened', function(_)
    assert.windows.are(lean_window)
    infoview.open()
    assert.windows.are(lean_window, infoview.get_current_infoview().window)
  end)
end)
