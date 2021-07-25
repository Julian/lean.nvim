local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('tests.helpers').setup {
  infoview = { autoopen = false },
}
describe('infoview', function()
  it('does not automatically open',
    function(_)
      vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)
      assert.is_not.open_infoview(false, true)
    end)

  it('can be opened after no autoopen',
    function(_)
      infoview.get_current_infoview():open()
      assert.open_infoview()
    end)
end)
