---Tests for behavior which activates without ever calling `lean.setup`,
---either at startup via our `plugin/` files (sourced for tests by
---scripts/minimal_init.lua, as Neovim itself would at startup) or lazily via
---our `ftplugin/` files.
local Buffer = require 'std.nvim.buffer'

local helpers = require 'spec.helpers'
local progress = require 'lean.progress'

local stderr_lines = {}

-- Our plugin files have already enabled the language server; disable it
-- again so no real server interferes with the faked state below.
vim.lsp.enable('leanls', false)

vim.g.lean_config = vim.tbl_deep_extend('force', vim.g.lean_config or {}, {
  stderr = {
    on_lines = function(chunk)
      table.insert(stderr_lines, chunk)
    end,
  },
})

describe('without calling lean.setup', function()
  it('defines commands', function()
    assert.are.equal(2, vim.fn.exists ':LeanGoal')
  end)

  it(
    'renders progress bars',
    helpers.clean_buffer('example : 2 = 2 := rfl', function()
      local buffer = Buffer:current()
      local uri = buffer:uri()
      progress.proc_infos[uri] = {
        {
          range = {
            start = { line = 0, character = 0 },
            ['end'] = { line = 0, character = 22 },
          },
        },
      }

      require('lean.progress_bars').update { textDocument = { uri = uri } }
      helpers.wait:for_progress_bars(buffer.bufnr)

      local ns = vim.api.nvim_create_namespace 'lean.progress'
      local marks = vim.api.nvim_buf_get_extmarks(buffer.bufnr, ns, 0, -1, { details = true })
      assert.are.equal('│', vim.trim(marks[1][4].sign_text))

      require('lean.progress_bars').clear(buffer.bufnr)
      progress.proc_infos[uri] = nil
    end)
  )

  it(
    'tees stderr output',
    helpers.clean_buffer(function()
      local log = require 'vim.lsp.log'
      local target = log._self or log
      target.error('rpc', 'lean', 'stderr', 'hello from fake stderr')
      assert
        .message('stderr output was never teed, got: ' .. vim.inspect(stderr_lines))
        .is_true(vim.iter(stderr_lines):any(function(chunk)
          return chunk:find 'hello from fake stderr' ~= nil
        end))
    end)
  )
end)
