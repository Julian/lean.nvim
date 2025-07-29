---@brief [[
--- Tests for infoview autoopen as a function (where its return value decides
--- whether to open the new infoview or not).
---@brief ]]

local Window = require 'std.nvim.window'

require 'spec.helpers'
local fixtures = require 'spec.fixtures'
local infoview = require 'lean.infoview'

local should_autoopen = false

require('lean').setup {
  infoview = {
    autoopen = function()
      return should_autoopen
    end,
  },
}

describe('infoview custom autoopen', function()
  it('uses the configured function to decide whether to autoopen', function()
    local lean_window = Window:current()

    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    assert.windows.are { lean_window }

    should_autoopen = true

    vim.cmd.edit { fixtures.project.some_nested_existing_file, bang = true }
    assert.windows.are { lean_window, infoview.get_current_infoview().window }
  end)
end)
