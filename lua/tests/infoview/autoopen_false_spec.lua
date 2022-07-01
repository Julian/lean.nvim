local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')
local helpers = require('tests.helpers')

require('lean').setup{ infoview = { autoopen = false, use_widgets = false } }

describe('infoview', function()

  local lean_window

  it('does not automatically open infoviews', function(_)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    vim.cmd('edit! ' .. fixtures.lean_project.path .. '/Test.lean')
    -- FIXME: This obviously shouldn't require running twice, but without
    --        it, somehow the test run differs from interactive use!
    --        Specifically, ft.detect doesn't run at all until the second
    --        time a file is opened :/. This must be related to what I've
    --        observed about `make nvim` -- that if you edit a file, you
    --        have to open it twice to open the infoview, so when we fix
    --        that, this should be fixed as well -- but for now, this needs
    --        to be here twice to prevent regressions like #245.
    --        To know whether you can remove this, undo the change from #245
    --        and ensure this test properly fails.
    vim.cmd('edit! ' .. fixtures.lean_project.path .. '/Test.lean')
    lean_window = vim.api.nvim_get_current_win()
    assert.windows.are(lean_window)
  end)

  it('allows infoviews to be manually opened', function(_)
    assert.windows.are(lean_window)
    helpers.move_cursor{ to = {3, 27} }
    infoview.open()
    assert.windows.are(lean_window, infoview.get_current_infoview().window)
    assert.infoview_contents.are[[
      ▶ expected type (3:28-3:36)
      ⊢ Nat
    ]]
    infoview.close()
  end)
end)
