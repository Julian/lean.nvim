---@brief [[
--- Tests for basic (auto-)attaching of LSP clients.
---@brief ]]

local fixtures = require 'spec.fixtures'
local helpers = require 'spec.helpers'

require('lean').setup {}

describe('LSP', function()
  assert.is.empty(vim.lsp.get_clients { bufnr = 0, name = 'leanls', _uninitialized = true })

  it('is attached to .lean files within projects', function()
    vim.cmd.edit(fixtures.project.some_existing_file)
    helpers.wait_for_ready_lsp()
    assert.is.same(1, #vim.lsp.get_clients { bufnr = 0, name = 'leanls', _uninitialized = true })
  end)

  it(
    'is attached to single .lean files',
    helpers.clean_buffer(function()
      helpers.wait_for_ready_lsp()
      assert.is.same(1, #vim.lsp.get_clients { bufnr = 0, name = 'leanls', _uninitialized = true })
    end)
  )

  it('is not attached to non-Lean files', function()
    vim.cmd.split 'some_non_lean_file.tmp'
    assert.is.empty(vim.lsp.get_clients { bufnr = 0, name = 'leanls', _uninitialized = true })
    vim.cmd.close { bang = true }
  end)

  it('uses project root dir for files in .lake/packages', function()
    vim.cmd.edit(fixtures.with_widgets:child '.lake/packages/Qq/Qq.lean')
    local client = helpers.wait_for_ready_lsp()
    local project_root = vim.uv.fs_realpath(fixtures.with_widgets._root)
    assert.is.same(project_root, vim.uv.fs_realpath(client.config.root_dir))
  end)
end)
