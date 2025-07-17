local helpers = require 'spec.helpers'
local project = require('spec.fixtures').project

local lean = require 'lean'

lean.setup {}

describe('lean.current_search_paths', function()
  for kind, path in project:files() do
    it(string.format('returns the paths for %s files', kind), function()
      vim.cmd.edit(path)
      helpers.wait_for_ready_lsp()

      local paths = lean.current_search_paths()
      assert.message(vim.inspect(paths)).are.equal(4, #paths)
      assert.has_all(table.concat(paths, '\n') .. '\n', {
        '/src/lean\n', -- standard library
        project.root .. '\n', -- the project itself
        project.child 'foo\n', -- its dependency
      })
    end)
  end

  it('returns only the stdlib outside of projects', function()
    vim.iter(vim.lsp.buf.list_workspace_folders()):map(vim.lsp.buf.remove_workspace_folder)

    vim.cmd.edit 'someLoneLeanFile.lean'
    helpers.wait_for_ready_lsp()

    local paths = lean.current_search_paths()
    assert.message(vim.inspect(paths)).are.equal(2, #paths)
    assert.is.truthy(paths[1]:match '/src/lean')
  end)
end)
