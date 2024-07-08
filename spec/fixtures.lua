local this_file = debug.getinfo(1).source:match '@(.*)$'
local root = vim.fn.fnamemodify(this_file, ':p:h') .. '/fixtures'

local fixtures = {}

fixtures.project = {
  path = root .. '/example-project',
  some_existing_file = root .. '/example-project/Test.lean',
  some_nonexisting_file = root .. '/example-project/DoesNotExist.lean',
  some_nested_existing_file = root .. '/example-project/Test/Squares.lean',
  some_nested_nonexisting_file = root .. '/example-project/Test/DoesNotExist.lean',
}

function fixtures.project_files()
  return pairs {
    ['existing'] = fixtures.project.some_existing_file,
    ['nested existing'] = fixtures.project.some_nested_existing_file,
    ['nonexisting'] = fixtures.project.some_nonexisting_file,
    ['nested nonexisting'] = fixtures.project.some_nested_nonexisting_file,
  }
end

return fixtures
