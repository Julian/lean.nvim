---@brief [[
--- Tests for refreshing file dependencies
--- (i.e. the LeanRefreshFileDependencies/LeanRestartFile commands)
--- which Lean allows users to run to trigger recompiling imports.
---@brief ]]

local Window = require 'std.nvim.window'

local helpers = require 'spec.helpers'
local project = require('spec.fixtures').example

local restart_file = require('lean.lsp').restart_file

require('lean').setup {}

describe('restart file', function()
  local dependency = project:child 'Example/RestartFile.lean'
  local dependent = project:child 'Example/RestartFileDependent.lean'

  local original_lines = vim.fn.readfile(dependency)

  after_each(function()
    vim.fn.writefile(original_lines, dependency)
  end)

  it('does not error when running LeanRestartFile', function()
    vim.cmd.edit { dependent, bang = true }
    local dependent_win = Window:current()

    dependent_win:move_cursor { 2, 8 }
    assert.infoview_contents.are [[
      ▼ 2:8-2:19: error:
      Unknown identifier `addedByTest`

      Error code: lean.unknownIdentifier
      View explanation
    ]]

    vim.cmd.vsplit { dependency, bang = true }
    -- NOTE: this modifies the file, but should be undone by `after_each`!
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'def addedByTest := 37' })
    vim.cmd.write()

    dependent_win:make_current()
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
