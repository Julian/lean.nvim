---@brief [[
--- Tests for infoview.go_to (jumping to the infoview window).
---@brief ]]

local Window = require 'std.nvim.window'

require 'spec.helpers'
local fixtures = require 'spec.fixtures'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe('infoview.go_to', function()
  local lean_window = Window:current()

  before_each(function()
    lean_window:make_current()
    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    infoview.open()
  end)

  it('moves the cursor to the infoview window when open', function()
    local iv = infoview.get_current_infoview()
    assert.windows.are { lean_window, iv.window }
    assert.current_window.is(lean_window)
    infoview.go_to()
    assert.current_window.is(iv.window)
  end)

  it('reopens the infoview and moves the cursor if it was closed', function()
    local iv = infoview.get_current_infoview()
    assert.windows.are { lean_window, iv.window }
    iv:close()
    assert.windows.are { lean_window }

    infoview.go_to()
    local new_iv = infoview.get_current_infoview()
    assert.windows.are { lean_window, new_iv.window }
    assert.current_window.is(new_iv.window)
  end)
end)
