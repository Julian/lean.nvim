require('tests.helpers')
local infoview = require('lean.infoview')

require('lean').setup{}

describe('infoview.close_all', function()
  it('closes one infoview', function(_)
    assert.is.equal(#vim.api.nvim_tabpage_list_wins(0), 1)
    local lean_window = vim.api.nvim_get_current_win()

    vim.cmd('edit! temp.lean')
    local current_infoview = infoview.open()
    assert.windows.are(lean_window, current_infoview.window)

    infoview.close_all()
    assert.windows.are(lean_window)
  end)

  it('closes many infoviews, some already closed', function(_)
    local tabpages = {}

    vim.cmd('tabnew temp1.lean')
    table.insert(tabpages, vim.api.nvim_get_current_tabpage())
    local temp1 = unpack(vim.api.nvim_tabpage_list_wins(tabpages[#tabpages]))
    local temp1_infoview = infoview.open()

    vim.cmd('tabnew temp2.lean')
    table.insert(tabpages, vim.api.nvim_get_current_tabpage())
    local temp2 = unpack(vim.api.nvim_tabpage_list_wins(tabpages[#tabpages]))
    local temp2_infoview = infoview.open()

    vim.cmd('tabnew temp3.lean')
    table.insert(tabpages, vim.api.nvim_get_current_tabpage())
    local temp3 = unpack(vim.api.nvim_tabpage_list_wins(tabpages[#tabpages]))
    infoview.open():close()

    vim.cmd('tabnew temp4.lean')
    table.insert(tabpages, vim.api.nvim_get_current_tabpage())
    local temp4 = unpack(vim.api.nvim_tabpage_list_wins(tabpages[#tabpages]))
    local temp4_infoview = infoview.open()

    assert.are.same(
      vim.tbl_map(vim.api.nvim_tabpage_list_wins, tabpages), {
        { temp1, temp1_infoview.window },
        { temp2, temp2_infoview.window },
        { temp3 },
        { temp4, temp4_infoview.window },
      }
    )

    infoview.close_all()

    assert.are.same(
      {
        { temp1 },
        { temp2 },
        { temp3 },
        { temp4 },
      }, vim.tbl_map(vim.api.nvim_tabpage_list_wins, tabpages)
    )
  end)
end)
