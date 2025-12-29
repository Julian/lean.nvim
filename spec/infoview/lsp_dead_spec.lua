local fixtures = require 'spec.fixtures'
local helpers = require 'spec.helpers'

local infoview = require 'lean.infoview'

require('lean').setup { progress_bars = { enable = false } }

describe('language server dead', function()
  it('is shown when the server is dead', function()
    vim.cmd.edit { fixtures.example:child 'Example/Squares.lean' }
    assert.infoview_contents.are [[
      ▼ 1:1-1:6: information:
      1
    ]]

    vim.lsp.stop_client(vim.lsp.get_clients { bufnr = 0 })
    local succeeded = vim.wait(5000, function()
      return vim.tbl_isempty(vim.lsp.get_clients { bufnr = 0 })
    end)
    assert.message("Couldn't kill the LSP!").is_true(succeeded)

    assert.infoview_contents_nowait.are '🪦 The Lean language server is dead.'
    assert.are.same(
      'NormalNC:leanInfoLSPDead',
      infoview.get_current_infoview().window.o.winhighlight
    )

    -- and comes back alive
    vim.cmd.edit()
    helpers.wait_for_processing()
    assert.infoview_contents.are [[
      ▼ 1:1-1:6: information:
      1
    ]]
  end)

  it('updates when moving to another window with active LSP', function()
    vim.cmd.edit { fixtures.example:child 'Example/Squares.lean' }
    vim.cmd.split { fixtures.example:child 'Foo/foo.lean' }

    local succeeded = vim.wait(5000, function()
      return #vim.lsp.get_clients {} == 2
    end)
    assert.message("Didn't find 2 LSP clients").is_true(succeeded)

    vim.lsp.stop_client(vim.lsp.get_clients { bufnr = 0 })
    succeeded = vim.wait(5000, function()
      return #vim.lsp.get_clients {} == 1
    end)
    assert.message("Couldn't kill the LSP!").is_true(succeeded)
    assert.infoview_contents_nowait.are '🪦 The Lean language server is dead.'

    -- still alive for the other window
    vim.cmd.wincmd 'p'
    assert.infoview_contents.are [[
      ▼ 1:1-1:6: information:
      1
    ]]

    vim.cmd.wincmd 'p'
    assert.infoview_contents_nowait.are '🪦 The Lean language server is dead.'
  end)

  it('does not error if the LSP dies with closed infoview', function()
    vim.cmd.edit { fixtures.example:child 'Example/Squares.lean' }
    assert.infoview_contents.are [[
      ▼ 1:1-1:6: information:
      1
    ]]
    infoview.close()
    vim.lsp.stop_client(vim.lsp.get_clients { bufnr = 0 })
    local succeeded = vim.wait(5000, function()
      return vim.tbl_isempty(vim.lsp.get_clients { bufnr = 0 })
    end)
    assert.message("Couldn't kill the LSP!").is_true(succeeded)

    infoview.open()
    assert.infoview_contents_nowait.are '🪦 The Lean language server is dead.'
  end)
end)
