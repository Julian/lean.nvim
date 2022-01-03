local lean = require('lean')
local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')

require('lean').setup {
  lsp = { enable = true },
  lsp3 = { enable = true },
}

describe('lean.current_search_paths', function()
  for kind, path in unpack(fixtures.lean_project.files_it) do
    it(string.format('returns the paths for %s files', kind), function()
      vim.api.nvim_command('edit ' .. path)
      helpers.wait_for_ready_lsp()

      local paths = lean.current_search_paths()
      assert.are_equal(3, #paths)
      -- via its leanpkg.path:
      assert.has_all(
        table.concat(paths, '\n') .. '\n',
        { "/lib/lean\n",                                      -- standard library
          fixtures.lean_project.path .. '\n',                 -- the project itself
          fixtures.lean_project.path .. '/foo\n' }  -- its dependency
      )
    end)
  end

  for kind, path in unpack(fixtures.lean3_project.files_it) do
    it(string.format('returns the paths for %s lean3 files', kind), function()
      vim.api.nvim_command('edit ' .. path)
      helpers.wait_for_ready_lsp()

      local paths = lean.current_search_paths()
      assert.are_equal(3, #paths)
      -- via its leanpkg.path:
      assert.has_all(
        table.concat(paths, '\n') .. '\n',
        {
          '/lib/lean/library\n',                     -- Lean 3 standard library
          fixtures.lean3_project.path .. '/src\n',   -- the project itself
          fixtures.lean3_project.path .. '/_target/deps/mathlib/src\n'    -- the project itself
        }
      )
    end)
  end
end)
