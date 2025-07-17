local project = require('spec.fixtures').project
local helpers = require 'spec.helpers'

require('lean').setup {}

describe('ft.detect', function()
  for kind, path in project:files() do
    it('detects ' .. kind .. ' lean files', function()
      vim.cmd.edit { path, bang = true }
      assert.are.equal('lean', vim.bo.filetype)
    end)
  end

  it('detects standard library files', function()
    vim.cmd.edit { project.child 'Example/JumpToStdlib.lean', bang = true }
    assert.are.equal('lean', vim.bo.filetype)
    local initial_path = vim.api.nvim_buf_get_name(0)

    vim.cmd.normal 'G$'
    helpers.wait_for_loading_pins()

    vim.lsp.buf.definition()
    assert.is_truthy(vim.wait(15000, function()
      return vim.api.nvim_buf_get_name(0) ~= initial_path
    end))

    helpers.wait_for_filetype()
    assert.are.equal('lean', vim.bo.filetype)
  end)

  it('marks standard library files nomodifiable by default', function()
    local name = vim.api.nvim_buf_get_name(0)
    local is_core = name:match '.*/src/lean/.*' or name:match '.*/lib/lean/src/.*'
    assert.message("Didn't jump to core Lean!").is_truthy(is_core)
    assert.is_falsy(vim.bo.modifiable)
  end)

  it('marks dependency files nomodifable by default', function()
    vim.cmd.edit { project.some_dependency_file, bang = true }
    assert.is_falsy(vim.bo.modifiable)
  end)

  it('does not mark other lean files nomodifiable', function()
    vim.cmd.edit { project.some_existing_file, bang = true }
    assert.is_truthy(vim.bo.modifiable)
  end)
end)
