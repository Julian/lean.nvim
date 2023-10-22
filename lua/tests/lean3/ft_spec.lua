local helpers = require('tests.helpers')
local fixtures = require('tests.lean3.fixtures')

require('lean').setup { lsp3 = { enable = true } }

helpers.if_has_lean3('ft.detect', function()
  for kind, path in fixtures.project_files() do
    it('detects ' .. kind .. ' files', function()
      vim.cmd('edit! ' .. path)
      assert.are_equal('lean3', vim.opt.filetype:get())
    end)
  end

  it('detects lean 3 standard library files', function()
    vim.cmd('edit! ' .. fixtures.project.path .. '/src/jump_to_stdlib.lean')
    assert.are_equal('lean3', vim.opt.filetype:get())
    local initial_path = vim.api.nvim_buf_get_name(0)

    vim.api.nvim_command('normal G$')
    helpers.wait_for_line_diagnostics()

    vim.lsp.buf.definition()
    assert.is_truthy(vim.wait(15000, function() return vim.api.nvim_buf_get_name(0) ~= initial_path end))

    helpers.wait_for_filetype()
    assert.are_equal('lean3', vim.opt.filetype:get())
  end)

  it('marks lean 3 standard library files nomodifiable by default', function()
    local name = vim.api.nvim_buf_get_name(0)
    assert.is_truthy(name:match('.*/lean/library/init/.*'))
    assert.is_falsy(vim.opt.modifiable:get())
  end)

  it('does not mark other lean 3 files nomodifiable', function()
    vim.cmd('edit! ' .. fixtures.project.some_existing_file)
    assert.is_truthy(vim.opt.modifiable:get())
  end)
end)
