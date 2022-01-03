local infoview = require('lean.infoview')
local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')
local position = require('lean._util').make_position_params

helpers.setup {
  infoview = { autoopen = true },
  lsp = { enable = true },
  lsp3 = { enable = true },
}

describe('diff pin', function()
  local diff_pin
  it('setup', function()
      --- setup
      helpers.edit_lean_buffer(fixtures.lean_project.some_existing_file)
      helpers.wait_for_ready_lsp()
      helpers.wait_for_server_progress()
      assert.initopened.infoview()
      vim.api.nvim_win_set_cursor(0, {16, 0})
      infoview.__update()
      assert.pin_pos_changed.infoview()
  end)

  it('can be created', function()
    infoview.get_current_infoview().info:set_diff_pin(position())
    diff_pin = infoview.get_current_infoview().info.diff_pin
    assert.pinopened{diff_pin.id}.diffwinopened.infoview()
  end)

  it('is retained on infoview close', function()
    infoview.get_current_infoview():close()
    assert.closed.diffwinclosed.infoview()
  end)

  it('opens along with infoview on infoview open', function()
    infoview.get_current_infoview():open()
    assert.opened.diffwinopened.infoview()
  end)

  it('can be cleared',
  function(_)
    infoview.get_current_infoview().info:clear_diff_pin()
    assert.pindeleted{diff_pin.id}.diffwinclosed.infoview()
  end)

  it('can be created again', function()
    infoview.get_current_infoview().info:set_diff_pin(position())
    diff_pin = infoview.get_current_infoview().info.diff_pin
    assert.pinopened{diff_pin.id}.diffwinopened.infoview()
  end)

  it('manual window close clears pins',
  function(_)
    vim.api.nvim_set_current_win(infoview.get_current_infoview().diff_win)
    assert.buf.left.tracked()
    assert.win.left.tracked()
    vim.api.nvim_command("quit")
    assert.buf.left.tracked_pending()
    assert.win.left.tracked_pending()

    assert.use_pendingbuf.use_pendingwin.pindeleted{diff_pin.id}.diffwinclosed.infoview()
  end)
end)
