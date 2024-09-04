local helpers = require 'spec.helpers'
local project = require('spec.fixtures').project

require('lean').setup { lsp = { enable = true } }

describe('lean.current_search_paths', function()
  for kind, path in project:files() do
    it(string.format('returns the paths for %s files', kind), function()
      vim.cmd.edit(path)
      helpers.wait_for_ready_lsp()

      local paths = require('lean').current_search_paths()
      assert.are.equal(3, #paths)
      assert.has_all(table.concat(paths, '\n') .. '\n', {
        '/lib/lean\n', -- standard library
        project.path .. '\n', -- the project itself
        project.path .. '/foo\n', -- its dependency
      })
    end)
  end
end)
