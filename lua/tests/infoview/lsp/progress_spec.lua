local infoview = require('lean.infoview')
local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')

helpers.setup {
  infoview = { autoopen = true; autopause = false },
  lsp = { enable = true },
  lsp3 = { enable = true },
}
describe('infoview', function()
  describe('lean 4', function()
    it('shows processing message initially',
    function(_)
      vim.api.nvim_command("edit " .. fixtures.lean_project.some_existing_file)
      helpers.wait_for_ready_lsp()
      vim.api.nvim_win_set_cursor(0, {3, 23})
      infoview.__update()
      assert.initopened.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.msg, {"Processing file..."})
    end)

    it('automatically updates when processing finished',
    function(_)
      helpers.wait_for_server_progress()
      assert.pin_text_changed.infoview()
    end)
  end)
end)
