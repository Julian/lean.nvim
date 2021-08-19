local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')
local helpers = require('tests.helpers')

helpers.setup {
  infoview = { autoopen = false },
}
describe('infoview', function()
  it('does not automatically open',
    function(_)
      helpers.edit_lean_buffer(fixtures.lean3_project.some_existing_file)
      assert.initclosed.infoview()
    end)

  it('can be opened after no autoopen',
    function(_)
      infoview.get_current_infoview():open()
      assert.opened.infoview()
    end)
end)
