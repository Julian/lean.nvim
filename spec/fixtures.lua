local this_file = debug.getinfo(1).source:match '@(.*)$'

local root = vim.fs.joinpath(vim.fs.dirname(this_file), 'fixtures')
local project_root = vim.fs.normalize(vim.fs.joinpath(root, 'example-project'))

local function child(name)
  return vim.fs.joinpath(project_root, name)
end

local fixtures = {
  project = {
    root = project_root,
    child = child,

    some_existing_file = child 'Test.lean',
    some_nonexisting_file = child 'DoesNotExist.lean',
    some_nested_existing_file = child 'Test/Squares.lean',
    some_nested_nonexisting_file = child 'Test/DoesNotExist.lean',
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

return fixtures
