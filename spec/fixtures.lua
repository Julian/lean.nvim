local this_file = debug.getinfo(1).source:match '@(.*)$'

local root = vim.fs.joinpath(vim.fs.dirname(this_file), 'fixtures')
local indent = vim.fs.joinpath(root, 'indent')
local project_root = vim.fs.normalize(vim.fs.joinpath(root, 'example-project'))

local function child(name)
  return vim.fs.joinpath(project_root, name)
end

local fixtures = {
  indent = function()
    return vim.iter(vim.fs.dir(indent)):map(function(each)
      local name, replaced = each:gsub('.in.lean$', '')
      if replaced == 0 then
        return
      end

      ---@class IndentFixture
      ---@field description string the name of the fixture
      ---@field unindented string the path to the unindented version
      ---@field expected string[] the expected indented lines

      ---@type IndentFixture
      return {
        description = name:gsub('_', ' '),
        unindented = vim.fs.joinpath(indent, each),
        expected = vim.fn.readfile(vim.fs.joinpath(indent, name .. '.lean')),
      }
    end)
  end,
  project = {
    root = project_root,
    child = child,

    some_existing_file = child 'Test.lean',
    some_nonexisting_file = child 'DoesNotExist.lean',
    some_nested_existing_file = child 'Test/Squares.lean',
    some_nested_nonexisting_file = child 'Test/DoesNotExist.lean',

    some_dependency_file = child '.lake/packages/importGraph/ImportGraph/Imports.lean',
  },
}

function fixtures.project:files()
  return vim.iter {
    ['existing'] = self.some_existing_file,
    ['nonexisting'] = self.some_nonexisting_file,
    ['nested existing'] = self.some_nested_existing_file,
    ['nested nonexisting'] = self.some_nested_nonexisting_file,
  }
end

assert.is.truthy(vim.uv.fs_stat(fixtures.project.some_existing_file))
assert.is.falsy(vim.uv.fs_stat(fixtures.project.some_nonexisting_file))
assert.is.truthy(vim.uv.fs_stat(fixtures.project.some_nested_existing_file))
assert.is.falsy(vim.uv.fs_stat(fixtures.project.some_nested_nonexisting_file))
assert.is.truthy(vim.uv.fs_stat(fixtures.project.some_dependency_file))

assert.is.truthy(vim.uv.fs_stat(indent))

return fixtures
