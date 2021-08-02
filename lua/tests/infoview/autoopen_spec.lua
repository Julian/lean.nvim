local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')
local helpers = require('tests.helpers')

helpers.setup {
  infoview = { autoopen = true },
}
describe('infoview', function()
  it('automatically opens',
    function(_)
      vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_existing_file)
      assert.initopened.infoview()
    end)

  it('new tab automatically opens',
    function(_)
      vim.api.nvim_command('tabnew')
      assert.buf.created.tracked()
      assert.win.created.tracked()
      vim.api.nvim_command('edit ' .. fixtures.lean3_project.some_nested_existing_file)
      assert.initopened.infoview()
    end)

  it('can be closed after autoopen',
    function(_)
      infoview.get_current_infoview():close()
      assert.closed.infoview()
    end)

  it('opens automatically after having closen previous infoviews',
  function(_)
    vim.api.nvim_command("tabnew")
    assert.buf.created.tracked()
    assert.win.created.tracked()
    vim.api.nvim_command("edit " .. fixtures.lean3_project.some_existing_file)
    assert.buf.left.created({infoview.get_current_infoview().info.bufnr}).tracked()
    assert.no_buf_track.initopened.infoview()
  end)

  it('auto-open disable',
  function(_)
    vim.api.nvim_command("tabnew")
    assert.buf.created.tracked()
    assert.win.created.tracked()
    infoview.set_autoopen(false)
    vim.api.nvim_command("edit " .. fixtures.lean3_project.some_nested_existing_file)
    assert.buf.left.created({infoview.get_current_infoview().info.bufnr}).tracked()
    assert.no_buf_track.initclosed.infoview()
  end)

  it('open after auto-open disable',
  function(_)
    infoview.get_current_infoview():open()
    assert.opened.infoview()
  end)

  it('close after auto-open disable',
  function(_)
    infoview.get_current_infoview():close()
    assert.closed.infoview()
  end)

  it('auto-open re-enable',
  function(_)
    vim.api.nvim_command("tabnew")
    assert.buf.created.tracked()
    assert.win.created.tracked()
    infoview.set_autoopen(true)
    vim.api.nvim_command("edit " .. fixtures.lean3_project.some_existing_file)
    assert.buf.left.created({infoview.get_current_infoview().info.bufnr}).tracked()
    assert.no_buf_track.initopened.infoview()
  end)

  it('no auto-open for irrelevant file',
  function(_)
    vim.api.nvim_command("tabedit temp")
    assert.buf.created.tracked()
    assert.win.created.tracked()
    assert.is.falsy(infoview.get_current_infoview())
  end)
end)
