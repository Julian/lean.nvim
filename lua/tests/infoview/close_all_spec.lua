local infoview = require('lean.infoview')
local helpers = require('tests.helpers')

helpers.setup{}
describe('infoview', function()
  describe('close_all', function()
    it('closes one infoview', function(_)
      assert.is.equal(#vim.api.nvim_tabpage_list_wins(0), 1)

      helpers.edit_lean_buffer("temp.lean")
      local lean_window = unpack(vim.api.nvim_tabpage_list_wins(0))
      local current_infoview = infoview.get_current_infoview()

      current_infoview:open()
      assert.are.same(
        vim.api.nvim_tabpage_list_wins(0),
        { lean_window, current_infoview.window }
      )

      infoview.close_all()
      assert.are.same(vim.api.nvim_tabpage_list_wins(0), { lean_window })
    end)

    it('closes many infoviews, some already closed', function(_)
      local tabpages = {}

      vim.api.nvim_command("tabnew")
      helpers.edit_lean_buffer("temp1.lean")
      table.insert(tabpages, vim.api.nvim_get_current_tabpage())
      local temp1 = unpack(vim.api.nvim_tabpage_list_wins(tabpages[#tabpages]))
      local temp1_infoview = infoview.get_current_infoview()
      temp1_infoview:open()

      vim.api.nvim_command("tabnew")
      helpers.edit_lean_buffer("temp2.lean")
      table.insert(tabpages, vim.api.nvim_get_current_tabpage())
      local temp2 = unpack(vim.api.nvim_tabpage_list_wins(tabpages[#tabpages]))
      local temp2_infoview = infoview.get_current_infoview()
      temp2_infoview:open()

      vim.api.nvim_command("tabnew")
      helpers.edit_lean_buffer("temp3.lean")
      table.insert(tabpages, vim.api.nvim_get_current_tabpage())
      local temp3 = unpack(vim.api.nvim_tabpage_list_wins(tabpages[#tabpages]))
      local temp3_infoview = infoview.get_current_infoview()
      temp3_infoview:open()
      temp3_infoview:close()

      vim.api.nvim_command("tabnew")
      helpers.edit_lean_buffer("temp4.lean")
      table.insert(tabpages, vim.api.nvim_get_current_tabpage())
      local temp4 = unpack(vim.api.nvim_tabpage_list_wins(tabpages[#tabpages]))
      local temp4_infoview = infoview.get_current_infoview()
      temp4_infoview:open()

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
        vim.tbl_map(vim.api.nvim_tabpage_list_wins, tabpages), {
          { temp1 },
          { temp2 },
          { temp3 },
          { temp4 },
        }
      )
    end)
  end)
end)
