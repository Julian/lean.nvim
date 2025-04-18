---@brief [[
--- Tests for refreshing file dependencies
--- (i.e. the LeanRefreshFileDependencies/LeanRestartFile commands)
--- which Lean allows users to run to trigger recompiling imports.
---@brief ]]

local helpers = require 'spec.helpers'
local project = require('spec.fixtures').project

local restart_file = require('lean.lsp').restart_file

require('lean').setup {}

describe('restart file', function()
  local dependency = project.child 'Test/RestartFile.lean'
  local dependent = project.child 'Test/RestartFileDependent.lean'

  local original_lines = vim.fn.readfile(dependency)

  after_each(function()
    vim.fn.writefile(original_lines, dependency)
  end)

  it('does not error when running LeanRestartFile', function()
    vim.cmd.edit { dependent, bang = true }
    local dependent_win = vim.api.nvim_get_current_win()

    helpers.move_cursor { to = { 2, 8 } }
    assert.infoview_contents.are [[
      ▼ 2:8-2:19: error:
      unknown identifier 'addedByTest'
    ]]

    vim.cmd.vsplit { dependency, bang = true }
    -- NOTE: this modifies the file, but should be undone by `after_each`!
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'def addedByTest := 37' })
    vim.cmd.write()

    vim.api.nvim_set_current_win(dependent_win)
    helpers.wait_for_line_diagnostics()

    restart_file()

    assert.infoview_contents.are [[
      ▼ expected type (2:8-2:19)
      ⊢ Nat

      ▼ 2:1-2:7: information:
      addedByTest : Nat
    ]]
  end)
end)
