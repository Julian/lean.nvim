---@brief [[
--- Tests for infoview autoopen as a function (where its return value decides
--- whether to open the new infoview or not).
---@brief ]]
require('tests.helpers')
local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

local should_autoopen = false

require('lean').setup{
  infoview = { autoopen = function() return should_autoopen end }
}

describe('infoview custom autoopen', function()
  local lean_window

  it('uses the configured function to decide whether to autoopen', function()
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    lean_window = vim.api.nvim_get_current_win()

    vim.cmd('edit! ' .. fixtures.lean3_project.some_existing_file)
    assert.are.same_elements({ lean_window }, vim.api.nvim_tabpage_list_wins(0))

    should_autoopen = true

    vim.cmd('edit! ' .. fixtures.lean3_project.some_existing_file)
    assert.are.same_elements(
      { lean_window, infoview.get_current_infoview().window },
      vim.api.nvim_tabpage_list_wins(0)
    )
  end)
end)
