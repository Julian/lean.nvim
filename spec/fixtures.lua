local this_file = debug.getinfo(1).source:match '@(.*)$'
local root = vim.fn.fnamemodify(this_file, ':p:h') .. '/fixtures'

local fixtures = {
  project = {
    path = root .. '/example-project',
    some_existing_file = root .. '/example-project/Test.lean',
    some_nonexisting_file = root .. '/example-project/DoesNotExist.lean',
    some_nested_existing_file = root .. '/example-project/Test/Squares.lean',
    some_nested_nonexisting_file = root .. '/example-project/Test/DoesNotExist.lean',
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
