local fixtures = require 'spec.fixtures'
local helpers = require 'spec.helpers'

require('lean').setup { lsp = { enable = true } }

describe('lean.current_search_paths', function()
  for kind, path in fixtures.project_files() do
    it(string.format('returns the paths for %s files', kind), function()
      vim.cmd.edit(path)
      helpers.wait_for_ready_lsp()

      local paths = require('lean').current_search_paths()
      assert.are.equal(3, #paths)
      assert.has_all(table.concat(paths, '\n') .. '\n', {
        '/lib/lean\n', -- standard library
        fixtures.project.path .. '\n', -- the project itself
        fixtures.project.path .. '/foo\n', -- its dependency
      })
    end)
  end
end)
