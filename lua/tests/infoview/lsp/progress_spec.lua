local infoview = require('lean.infoview')
local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')

helpers.setup {
  --infoview = { autoopen = true; autopause = false; show_processing = true },
  infoview = { autoopen = true; autopause = false },
  lsp = { enable = true },
  lsp3 = { enable = true },
}
describe('infoview', function()
  describe('lean 4', function()
    -- NOTE: this test is disabled because it's fragile;
    -- swap it with the test below, and swap the configs above if you want to specifically test this
    pending('shows processing message initially',
    function(_)
      helpers.edit_lean_buffer(fixtures.lean_project.some_existing_file)
      helpers.wait_for_ready_lsp()
      vim.api.nvim_win_set_cursor(0, {3, 23})
      infoview.__update()
      assert.initopened.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.div:render(), {"Processing file..."})
    end)

    it('startup',
    function(_)
      helpers.edit_lean_buffer(fixtures.lean_project.some_existing_file)
      helpers.wait_for_ready_lsp()
      vim.api.nvim_win_set_cursor(0, {3, 23})
      infoview.__update()
      assert.initopened.infoview()
    end)

    it('automatically updates when processing finished',
    function(_)
      helpers.wait_for_server_progress()
      assert.pin_text_changed.infoview()
    end)
  end)
end)
