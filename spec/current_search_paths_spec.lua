local helpers = require 'spec.helpers'
local project = require('spec.fixtures').project

require('lean').setup {}

describe('lean.current_search_paths', function()
  for kind, path in project:files() do
    it(string.format('returns the paths for %s files', kind), function()
      vim.cmd.edit(path)
      helpers.wait_for_ready_lsp()

      local paths = require('lean').current_search_paths()
      -- Sigh. We depend on import graph for another test, so now we can't
      -- really say exactly how many paths should appear here. I guess that's
      -- not too big of a loss, so eventually we can just delete this
      -- assertion.
      -- assert.message(vim.inspect(paths)).are.equal(3, #paths)
      assert.has_all(table.concat(paths, '\n') .. '\n', {
        '/src/lean\n', -- standard library
        project.root .. '\n', -- the project itself
        project.child 'foo\n', -- its dependency
      })
    end)
  end

  it('returns only the stdlib outside of projects', function()
    vim.cmd.edit 'someLoneLeanFile.lean'
    helpers.wait_for_ready_lsp()

    local paths = require('lean').current_search_paths()
    -- Sigh. We depend on import graph for another test, so now we can't
    -- really say exactly how many paths should appear here. I guess that's
    -- not too big of a loss, so eventually we can just delete this
    -- assertion.
    -- assert.message(vim.inspect(paths)).are.equal(3, #paths)
    assert.is.equal(#paths, 1)
    assert.is.truthy(paths[1]:match '/src/lean')
  end)
end)
