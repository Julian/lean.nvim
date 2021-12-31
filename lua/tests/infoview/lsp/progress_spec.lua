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
    pending('shows processing message initially', function(_)
      helpers.edit_lean_buffer(fixtures.lean_project.some_existing_file)
      helpers.wait_for_ready_lsp()
      local result = vim.wait(5000, function() return require"lean.progress".is_processing(
        vim.uri_from_fname(fixtures.lean_project.some_existing_file)) end,
        50)
      assert.message"file was never processing".is_truthy(result)
      vim.api.nvim_win_set_cursor(0, {3, 35})
      infoview.__update()
      assert.initopened.pin_text_changed.infoview()
      assert.has_all(infoview.get_current_infoview().info.pin.div:to_string(), {"Processing file..."})
    end)

    pending('startup', function(_)
      helpers.edit_lean_buffer(fixtures.lean_project.some_existing_file)
      helpers.wait_for_ready_lsp()
      local result = vim.wait(5000, function() return require"lean.progress".is_processing(
        vim.uri_from_fname(fixtures.lean_project.some_existing_file)) end,
        50)
      assert.message"file was never processing".is_truthy(result)
      vim.api.nvim_win_set_cursor(0, {3, 35})
      infoview.__update()
      assert.initopened.infoview()
    end)

    pending('automatically updates when processing finished',
    function(_)
      helpers.wait_for_server_progress()
      assert.pin_text_changed.infoview()
    end)
  end)
end)
