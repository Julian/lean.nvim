local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')

require('lean').setup { lsp = { enable = true } }

describe('lean.current_search_paths', function()
  for kind, path in unpack(fixtures.lean_project.files_it) do
    it(string.format('returns the paths for %s files', kind), function()
      vim.api.nvim_command('edit ' .. path)
      helpers.wait_for_ready_lsp()

      local paths = require('lean').current_search_paths()
      assert.are_equal(3, #paths)
      -- via its leanpkg.path:
      assert.has_all(
        table.concat(paths, '\n') .. '\n',
        { "/lib/lean\n",                            -- standard library
          fixtures.lean_project.path .. '\n',       -- the project itself
          fixtures.lean_project.path .. '/foo\n' }  -- its dependency
      )
    end)
  end
end)
