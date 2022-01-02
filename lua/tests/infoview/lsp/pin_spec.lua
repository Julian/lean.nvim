local infoview = require('lean.infoview')
local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')
local position = require('lean._util').make_position_params

helpers.setup {
  infoview = { autoopen = true },
  lsp = { enable = true },
  lsp3 = { enable = true },
}

describe('infoview pin', function()
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

  describe('new pin', function()
    local old_pin = infoview.get_current_infoview().info.pin
    local new_pin
    it('can be created',
    function(_)
      infoview.get_current_infoview().info:add_pin()
      assert.pinopened.infoview()
      new_pin = infoview.get_current_infoview().info.pin
    end)

    it('can be updated independently',
    function(_)
      vim.api.nvim_win_set_cursor(0, {15, 15})
      infoview.__update()
      new_pin:update(true)
      old_pin:update(true)
      assert.pin_text_changed{new_pin.id, old_pin.id}.pin_pos_changed.infoview()
      assert.has_all(new_pin.div:to_string(), {"\n⊢ ∀ (n : Nat), n = n"})
      assert.has_all(old_pin.div:to_string(), {"\n⊢ n = n"})
    end)

    it('can be cleared',
    function(_)
      infoview.get_current_infoview().info:clear_pins()
      assert.pindeleted{old_pin.id}.infoview()
    end)

    it('can be created again',
    function(_)
      infoview.get_current_infoview().info:add_pin()
      assert.pinopened.infoview()
    end)
  end)

  describe('diff pin', function()
    local diff_pin
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
end)
