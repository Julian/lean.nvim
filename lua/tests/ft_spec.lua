local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')

describe('ft.detect', function()
  for kind, path in unpack(fixtures.lean_project.files_it) do
    it('detects ' .. kind .. ' lean 4 files', function()
      helpers.edit_lean_buffer(path)
      assert.are_equal("lean", vim.opt.filetype:get())
    end)
  end

  for kind, path in unpack(fixtures.lean3_project.files_it) do
    it('detects ' .. kind .. ' lean 3 files', function()
      helpers.edit_lean_buffer(path)
      assert.are_equal("lean3", vim.opt.filetype:get())
    end)
  end

  helpers.setup {
    lsp = { enable = true },
    lsp3 = { enable = true },
  }

  it('detects lean 4 standard library files', function()
    helpers.edit_lean_buffer(fixtures.lean_project.path .. '/Test/JumpToStdlib.lean')
    vim.api.nvim_command('normal G$')
    assert.are_equal("lean", vim.opt.filetype:get())

    local initial_path = vim.api.nvim_buf_get_name(0)
    helpers.wait_for_ready_lsp()
    helpers.wait_for_server_progress()

    vim.lsp.buf.definition()
    assert.is_truthy(vim.wait(5000, function() return vim.api.nvim_buf_get_name(0) ~= initial_path end))

    helpers.wait_for_filetype()

    assert.are_equal("lean", vim.opt.filetype:get())
  end)

  it('detects lean 3 standard library files', function()
    helpers.edit_lean_buffer(fixtures.lean3_project.path .. '/src/jump_to_stdlib.lean')
    vim.api.nvim_command('normal G$')
    assert.are_equal("lean3", vim.opt.filetype:get())

    local initial_path = vim.api.nvim_buf_get_name(0)
    helpers.wait_for_ready_lsp()
    helpers.wait_for_server_progress(": Type")

    vim.lsp.buf.definition()
    assert.is_truthy(vim.wait(5000, function() return vim.api.nvim_buf_get_name(0) ~= initial_path end))

    helpers.wait_for_filetype()

    assert.are_equal("lean3", vim.opt.filetype:get())
  end)
end)
