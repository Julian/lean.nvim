local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')

describe('ft.detect', function()
  for kind, path in unpack(fixtures.lean_project.files_it) do
    it('detects ' .. kind .. ' lean 4 files', function()
      vim.api.nvim_command('edit ' .. path)
      assert.is.same('lean', vim.opt.filetype:get())
    end)
  end

  for kind, path in unpack(fixtures.lean3_project.files_it) do
    it('detects ' .. kind .. ' lean 3 files', function()
      vim.api.nvim_command('edit ' .. path)
      assert.is.same('lean3', vim.opt.filetype:get())
    end)
  end

  helpers.setup {
    lsp = { enable = true },
    lsp3 = { enable = true },
  }

  it('detects lean 4 standard library files', function()
    vim.api.nvim_command('edit ' .. fixtures.lean_project.path .. '/Test/JumpToStdlib.lean')
    vim.api.nvim_command('normal G$')
    assert.is.same('lean', vim.opt.filetype:get())

    local initial_path = vim.api.nvim_buf_get_name(0)
    helpers.wait_for_ready_lsp()

    vim.lsp.buf.definition()
    vim.wait(5000, function() return vim.api.nvim_buf_get_name(0) ~= initial_path end)

    assert.is.same('lean', vim.opt.filetype:get())
  end)

  it('detects lean 3 standard library files', function()
    vim.api.nvim_command('edit ' .. fixtures.lean3_project.path .. '/src/jump_to_stdlib.lean')
    vim.api.nvim_command('normal G$')
    assert.is.same('lean3', vim.opt.filetype:get())

    local initial_path = vim.api.nvim_buf_get_name(0)
    helpers.wait_for_ready_lsp()

    vim.lsp.buf.definition()
    vim.wait(5000, function() return vim.api.nvim_buf_get_name(0) ~= initial_path end)

    assert.is.same('lean3', vim.opt.filetype:get())
  end)
end)
