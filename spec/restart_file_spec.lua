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
  local original_select = vim.ui.select

  after_each(function()
    vim.fn.writefile(original_lines, dependency)
    vim.ui.select = original_select
    -- Rebuild the dependency olean in case a test deleted or invalidated it.
    vim.system({ 'lake', 'build', 'Example.RestartFile' }, { cwd = project._root }):wait()
  end)

  it('restarts files which must be restarted', function()
    -- Delete the dependency's olean so lake setup-file --no-build exits
    -- with code 3. Because lean.nvim uses dependencyBuildMode = 'never',
    -- this triggers the "must be rebuilt" Error diagnostic.
    local olean = project:child '.lake/build/lib/lean/Example/RestartFile.olean'
    assert.is.truthy(vim.uv.fs_stat(olean), 'olean must exist before test')
    os.remove(olean)

    -- Choose "not now" to avoid rebuilding (which would pollute .olean
    -- state for subsequent tests).
    local seen_prompt
    vim.ui.select = function(_, opts, on_choice)
      seen_prompt = opts.prompt
      on_choice 'not now'
    end

    vim.cmd.edit { dependent, bang = true }
    helpers.wait:for_lsp()

    -- Wait for the diagnostic to arrive (the flag is set synchronously
    -- in the diagnostic handler, before the vim.schedule'd callback).
    local succeeded = vim.wait(30000, function()
      return vim.b.lean_imports_out_of_date == true
    end)
    assert.message('imports out of date was never detected').is_true(succeeded)

    -- The callback fires via vim.schedule; give it a chance to run.
    vim.wait(5000, function()
      return seen_prompt ~= nil
    end)
    assert.is.truthy(seen_prompt)
    assert.is.truthy(seen_prompt:match 'Imports are out of date')
  end)

  it('restarts files which should be restarted', function()
    -- Open the dependent first — it has an error because addedByTest
    -- doesn't exist yet, but imports themselves are not stale.
    vim.cmd.edit { dependent, bang = true }
    local dependent_win = Window:current()
    helpers.wait:for_lsp()

    dependent_win:move_cursor { 2, 8 }
    helpers.wait:for_processing()
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
