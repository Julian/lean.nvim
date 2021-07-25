local infoview = require('lean.infoview')

require('tests.helpers').setup {
  infoview = {},
}
describe('infoview', function()
  it('close_all succeeds',
  function(_)
    vim.api.nvim_command("edit temp.lean")
    infoview.get_current_infoview():open()
    assert.opened_infoview()

    vim.api.nvim_command("tabnew")
    assert.new_win()
    vim.api.nvim_command("edit temp.lean")
    infoview.get_current_infoview():open()
    assert.opened_infoview()

    vim.api.nvim_command("tabnew")
    assert.new_win()
    vim.api.nvim_command("edit temp.lean")
    infoview.get_current_infoview():open()
    assert.opened_infoview()
    infoview.get_current_infoview():close()
    assert.closed_infoview()

    vim.api.nvim_command("tabnew")
    assert.new_win()
    vim.api.nvim_command("edit temp.lean")
    infoview.get_current_infoview():open()
    assert.opened_infoview()


    local already_closed = false
    local already_closed_count = 0
    infoview.close_all(
    function(info)
      if info.window ~= vim.api.nvim_get_current_win() then
        vim.api.nvim_set_current_win(info.window)
        assert.change_infoview()
      end
      if not info.is_open then
        already_closed = true
        already_closed_count = already_closed_count + 1
      end
    end,
    function()
      assert.is_not.opened_infoview(already_closed)
      already_closed = false
    end
    )
    assert.equals(1, already_closed_count)
  end)
end)
