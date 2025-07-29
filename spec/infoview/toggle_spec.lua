require 'spec.helpers'
local Tab = require 'std.nvim.tab'
local Window = require 'std.nvim.window'
local fixtures = require 'spec.fixtures'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe('Infoview.toggle', function()
  local lean_window

  it('closes an open infoview', function()
    assert.is.equal(1, #Tab:current():windows())
    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    lean_window = Window:current()
    local current_infoview = infoview.get_current_infoview()

    assert.windows.are { lean_window, current_infoview.window }

    current_infoview:toggle()
    assert.windows.are { lean_window }
  end)

  it('opens a closed infoview', function()
    assert.windows.are { lean_window }
    local current_infoview = infoview.get_current_infoview()
    current_infoview:toggle()
    assert.windows.are { lean_window, current_infoview.window }
  end)

  it('toggles back and forth', function()
    local current_infoview = infoview.get_current_infoview()
    assert.windows.are { lean_window, current_infoview.window }

    current_infoview:toggle()
    assert.windows.are { lean_window }

    current_infoview:toggle()
    assert.windows.are { lean_window, current_infoview.window }

    current_infoview:toggle()
    assert.windows.are { lean_window }
  end)
end)
