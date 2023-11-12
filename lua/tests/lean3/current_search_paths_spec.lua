local fixtures = require 'tests.lean3.fixtures'
local helpers = require 'tests.helpers'

require('lean').setup { lsp3 = { enable = true } }

helpers.if_has_lean3('lean.current_search_paths', function()
  for kind, path in fixtures.project_files() do
    it(string.format('returns the paths for %s lean 3 files', kind), function()
      vim.cmd.edit(path)
      helpers.wait_for_ready_lsp()

      local paths = require('lean').current_search_paths()
      assert.are.equal(3, #paths)
      -- via its leanpkg.path:
      assert.has_all(table.concat(paths, '\n') .. '\n', {
        '/lib/lean/library\n', -- Lean 3 standard library
        fixtures.project.path .. '/src\n', -- the project itself
        fixtures.project.path .. '/_target/deps/mathlib/src\n', -- the project itself
      })
    end)
  end
end)
