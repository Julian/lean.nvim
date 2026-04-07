---@brief [[
--- Tests for LSP project root detection.
---@brief ]]

local Buffer = require 'std.nvim.buffer'
local fixtures = require 'spec.fixtures'

require('lean').setup {}

local leanls = vim.lsp.config.leanls

describe('root_dir', function()
  it('detects normal lake projects', function()
    local path = fixtures.example:child 'Example.lean'
    local buffer = Buffer.create { name = path }

    local resolved_root
    leanls.root_dir(buffer.bufnr, function(dir)
      resolved_root = dir
    end)

    local expected = vim.uv.fs_realpath(fixtures.example._root)
    assert.is.same(expected, vim.uv.fs_realpath(resolved_root))
  end)

  it('detects the core lean4 src/ directory for files inside src/', function()
    -- When walking upward from src/Init/Test.lean, src/ is found first
    -- via its lean-toolchain, matching the real lean4 repo structure.
    local path = fixtures.simple_fake_core_lean:child 'src/Init/Test.lean'
    local buffer = Buffer.create { name = path }

    local resolved_root
    leanls.root_dir(buffer.bufnr, function(dir)
      resolved_root = dir
    end)

    local expected = vim.uv.fs_realpath(fixtures.simple_fake_core_lean:child 'src')
    assert.is.same(expected, vim.uv.fs_realpath(resolved_root))
  end)

  it('detects the core lean4 repo root for files at the root level', function()
    local path = fixtures.simple_fake_core_lean:child 'Test.lean'
    local buffer = Buffer.create { name = path }

    local resolved_root
    leanls.root_dir(buffer.bufnr, function(dir)
      resolved_root = dir
    end)

    local expected = vim.uv.fs_realpath(fixtures.simple_fake_core_lean._root)
    assert.is.same(expected, vim.uv.fs_realpath(resolved_root))
  end)
end)
