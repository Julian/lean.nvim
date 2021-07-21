local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('tests.helpers').setup {
  infoview = { autoopen = true },
}
describe('infoview', function()
  vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)

  it('automatically opens',
    function(_)
      vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)
      assert.open_infoview()
    end)

  it('new tab automatically opens',
    function(_)
      vim.api.nvim_command('tabedit ' .. fixtures.lean3_project.some_existing_file)
      assert.open_infoview()
    end)

  it('can be closed after autoopen',
    function(_)
      infoview.get_current_infoview():close()
      assert.is_not.open_infoview()
    end)

  vim.api.nvim_command("tabnew")
  it('opens automatically after having closen previous infoviews',
  function(_)
    vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/test1.lean")
    assert.open_infoview()
  end)

  vim.api.nvim_command("tabnew")
  infoview.set_autoopen(false)
  it('auto-open disable',
  function(_)
    vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/test1.lean")
    assert.is_not.open_infoview()
  end)

  it('open after auto-open disable',
  function(_)
    infoview.get_current_infoview():open()
    assert.open_infoview()
  end)

  it('close after auto-open disable',
  function(_)
    infoview.get_current_infoview():close()
    assert.is_not.open_infoview()
  end)

  vim.api.nvim_command("tabnew")
  infoview.set_autoopen(true)
  it('auto-open re-enable',
  function(_)
    vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/test1.lean")
    assert.open_infoview()
  end)

  it('no auto-open for irrelevant file',
  function(_)
    vim.api.nvim_command("tabedit temp")
    assert.is.falsy(infoview.get_current_infoview())
  end)
end)
