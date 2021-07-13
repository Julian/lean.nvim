local lean = require('lean')
local helpers = require('tests.helpers')
local fixtures = require('tests.fixtures')

require('tests.helpers').setup {
  lsp = { enable = true },
  lsp3 = { enable = true },
}
describe('lean.current_search_paths', function()
  for kind, path in pairs{
    ["existing"] = fixtures.lean_project.some_existing_file,
    ["nested existing"] = fixtures.lean_project.some_nested_existing_file,
    ["nonexisting"] = fixtures.lean_project.some_nonexisting_file,
    ["nested nonexisting"] = fixtures.lean_project.some_nested_nonexisting_file
  } do
    it(string.format('returns the paths for %s files', kind), function()
      vim.api.nvim_command('edit ' .. path)
      helpers.wait_for_ready_lsp()

      local paths = lean.current_search_paths()
      -- via its leanpkg.path:
      assert.has_all(
        table.concat(paths, "\n"),
        { "/lib/lean",                  -- Lean standard library
          fixtures.lean_project.path }  -- the project itself
      )
    end)
  end

  for kind, path in pairs{
    ["existing"] = fixtures.lean3_project.some_existing_file,
    ["nested existing"] = fixtures.lean3_project.some_nested_existing_file,
    ["nonexisting"] = fixtures.lean3_project.some_nonexisting_file,
    ["nested nonexisting"] = fixtures.lean3_project.some_nested_nonexisting_file
  } do
    it(string.format('returns the paths for %s lean3 files', kind), function()
      vim.api.nvim_command('edit ' .. path)
      helpers.wait_for_ready_lsp()

      local paths = lean.current_search_paths()
      -- via its leanpkg.path:
      assert.has_all(
        table.concat(paths, "\n"),
        { "/lib/lean/library",           -- Lean 3 standard library
          fixtures.lean3_project.path }  -- the project itself
      )
    end)
  end
end)
