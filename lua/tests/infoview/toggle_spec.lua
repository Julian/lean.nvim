local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('tests.helpers').setup {
  infoview = { autoopen = true },
}
describe('Infoview.toggle', function()
  it('closes an open infoview', function()
    vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)
    assert.opened_infoview()
    infoview.get_current_infoview():toggle()
    assert.closed_infoview()
  end)

  it('opens a closed infoview', function()
    infoview.get_current_infoview():toggle()
    assert.opened_infoview()
  end)

  it('toggles back and forth', function()
    infoview.get_current_infoview():toggle()
    assert.closed_infoview()
    infoview.get_current_infoview():toggle()
    assert.opened_infoview()
    infoview.get_current_infoview():toggle()
    assert.closed_infoview()
    infoview.get_current_infoview():toggle()
    assert.opened_infoview()
  end)
end)
