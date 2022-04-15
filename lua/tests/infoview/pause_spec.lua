---@brief [[
--- Tests for the pausing and unpausing of infoviews via their Lua API.
---@brief ]]

local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')
local helpers = require('tests.helpers')

require('lean').setup{
  lsp = { enable = true },
  lsp3 = { enable = true }
}

describe('infoview pause/unpause', function()

  it("can pause and unpause updates", function(_)
    vim.cmd('edit! ' .. fixtures.lean_project.path .. '/Test/Squares.lean')
    helpers.move_cursor{ to = {3, 0} }
    -- FIXME: Trailing extra newline.
    assert.infoview_contents.are[[
      ▶ 3:1-3:6: information:
      9.000000

    ]]

    helpers.move_cursor{ to = {1, 0} }
    -- FIXME: Trailing extra newline.
    assert.infoview_contents.are[[
      ▶ 1:1-1:6: information:
      1

    ]]

    -- FIXME: Demeter is angry.
    local pin = infoview.get_current_infoview().info.pin
    pin:pause()

    helpers.move_cursor{ to = {3, 0} }
    pin:update()

    -- It's not obvious necessarily, but what's asserted here is that :update()
    -- does nothing when the pin is paused. In theory this test can pass just
    -- because updating didn't happen yet, but we don't want to blind wait,
    -- it's not worth the tradeoff for fairly simple functionality.
    assert.infoview_contents.are[[
      ▶ 1:1-1:6: information:
      1

    ]]

    -- Unpausing triggers an update.
    pin:unpause()
    -- FIXME: Trailing extra newline.
    assert.infoview_contents.are[[
      ▶ 3:1-3:6: information:
      9.000000

    ]]

    -- And continued movement continues updating.
    helpers.move_cursor{ to = {1, 0} }
    -- FIXME: Trailing extra newline.
    assert.infoview_contents.are[[
      ▶ 1:1-1:6: information:
      1

    ]]
  end)

end)
