local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('tests.helpers').setup {
  infoview = { autoopen = true },
}
describe('Infoview.toggle', function()
  it('closes an open infoview', function()
    vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)
    assert.open_infoview()
    infoview.get_current_infoview():toggle()
    assert.is_not.open_infoview()
  end)

  it('opens a closed infoview', function()
    infoview.get_current_infoview():toggle()
    assert.open_infoview()
  end)

  it('toggles back and forth', function()
    infoview.get_current_infoview():toggle()
    assert.is_not.open_infoview()
    infoview.get_current_infoview():toggle()
    assert.open_infoview()
    infoview.get_current_infoview():toggle()
    assert.is_not.open_infoview()
    infoview.get_current_infoview():toggle()
    assert.open_infoview()
  end)
end)
