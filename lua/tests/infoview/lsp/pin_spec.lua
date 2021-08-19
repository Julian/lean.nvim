local infoview = require('lean.infoview')
local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')

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
      assert.pin_pos_changed{new_pin.id}.pin_text_changed{new_pin.id, old_pin.id}.infoview()
      assert.has_all(new_pin.msg, {"\n⊢ Type"})
      assert.has_all(old_pin.msg, {"\n⊢ Bool"})
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
end)
