local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')
local helpers = require('tests.helpers')

helpers.setup {
  infoview = { autoopen = true },
}
describe('Infoview.toggle', function()
  it('closes an open infoview', function()
    helpers.edit_lean_buffer(fixtures.lean3_project.some_existing_file)
    assert.initopened.infoview()
    infoview.get_current_infoview():toggle()
    assert.closed.infoview()
  end)

  it('opens a closed infoview', function()
    infoview.get_current_infoview():toggle()
    assert.opened.infoview()
  end)

  it('toggles back and forth', function()
    infoview.get_current_infoview():toggle()
    assert.closed.infoview()
    infoview.get_current_infoview():toggle()
    assert.opened.infoview()
    infoview.get_current_infoview():toggle()
    assert.closed.infoview()
    infoview.get_current_infoview():toggle()
    assert.opened.infoview()
  end)
end)
