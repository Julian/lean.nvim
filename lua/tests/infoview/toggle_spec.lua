local infoview = require('lean.infoview')

require('tests.helpers').setup {
  infoview = { enable = true },
}
describe('Infoview.toggle', function()
  vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")

  it('closes an open infoview', function()
    assert.open_infoview()
    infoview.get_current_infoview():toggle()
    assert.is_not.open_infoview()
  end)

  it('opens a closed infoview', function()
    assert.is_not.open_infoview()
    infoview.get_current_infoview():toggle()
    assert.open_infoview()
  end)

  it('toggles back and forth', function()
    assert.open_infoview()
    infoview.get_current_infoview():toggle()
    infoview.get_current_infoview():toggle()
    infoview.get_current_infoview():toggle()
    infoview.get_current_infoview():toggle()
    assert.open_infoview()
  end)
end)
