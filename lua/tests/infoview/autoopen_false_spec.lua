local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('tests.helpers').setup {
  infoview = { autoopen = false },
}
describe('infoview', function()
  it('does not automatically open',
    function(_)
      vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)
      assert.unopened_infoview()
    end)

  it('can be opened after no autoopen',
    function(_)
      infoview.get_current_infoview():open()
      assert.opened_infoview()
    end)
end)
