local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')

require('lean').setup { lsp = { enable = true } }

describe('ft.detect', function()
  for kind, path in fixtures.project_files() do
    it('detects ' .. kind .. ' lean files', function()
      vim.cmd('edit! ' .. path)
      assert.are_equal('lean', vim.opt.filetype:get())
    end)
  end

  it('detects standard library files', function()
    vim.cmd('edit! ' .. fixtures.project.path .. '/Test/JumpToStdlib.lean')
    assert.are_equal('lean', vim.opt.filetype:get())
    local initial_path = vim.api.nvim_buf_get_name(0)

    vim.cmd.normal('G$')
    helpers.wait_for_loading_pins()

    vim.lsp.buf.definition()
    assert.is_truthy(vim.wait(15000, function() return vim.api.nvim_buf_get_name(0) ~= initial_path end))

    helpers.wait_for_filetype()
    assert.are_equal('lean', vim.opt.filetype:get())
  end)

  it('marks standard library files nomodifiable by default', function()
    local name = vim.api.nvim_buf_get_name(0)
    local is_stdlib = name:match('.*/src/lean/.*') or name:match('.*/lib/lean/src/.*')
    assert.message("Didn't jump to core Lean!").is_truthy(is_stdlib)
    assert.is_falsy(vim.opt.modifiable:get())
  end)

  it('does not mark other lean files nomodifiable', function()
    vim.cmd('edit! ' .. fixtures.project.some_existing_file)
    assert.is_truthy(vim.opt.modifiable:get())
  end)
end)
