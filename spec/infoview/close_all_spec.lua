require 'spec.helpers'
local Tab = require 'std.nvim.tab'
local Window = require 'std.nvim.window'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe('infoview.close_all', function()
  it('closes one infoview', function()
    assert.is.equal(1, #Tab:current():windows())
    local lean_window = Window:current()

    vim.cmd.edit { 'temp.lean', bang = true }
    local current_infoview = infoview.open()
    assert.windows.are(lean_window.id, current_infoview.window)

    infoview.close_all()
    assert.windows.are(lean_window.id)
  end)

  it('closes many infoviews, some already closed', function()
    local tabpages = {}

    vim.cmd.tabnew 'temp1.lean'
    table.insert(tabpages, Tab:current())
    local temp1 = unpack(tabpages[#tabpages]:windows())
    local temp1_infoview = infoview.open()

    vim.cmd.tabnew 'temp2.lean'
    table.insert(tabpages, Tab:current())
    local temp2 = unpack(tabpages[#tabpages]:windows())
    local temp2_infoview = infoview.open()

    vim.cmd.tabnew 'temp3.lean'
    table.insert(tabpages, Tab:current())
    local temp3 = unpack(tabpages[#tabpages]:windows())
    infoview.open():close()

    vim.cmd.tabnew 'temp4.lean'
    table.insert(tabpages, Tab:current())
    local temp4 = unpack(tabpages[#tabpages]:windows())
    local temp4_infoview = infoview.open()

    assert.are.same(vim.tbl_map(Tab.windows, tabpages), {
      { temp1, Window:from_id(temp1_infoview.window) },
      { temp2, Window:from_id(temp2_infoview.window) },
      { temp3 },
      { temp4, Window:from_id(temp4_infoview.window) },
    })

    infoview.close_all()

    assert.are.same({
      { temp1 },
      { temp2 },
      { temp3 },
      { temp4 },
    }, vim.tbl_map(Tab.windows, tabpages))
  end)
end)
