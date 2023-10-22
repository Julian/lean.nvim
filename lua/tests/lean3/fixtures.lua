local this_file = debug.getinfo(1).source:match("@(.*)$")
local root = vim.fn.fnamemodify(this_file, ":p:h") .. "/fixtures"

local fixtures = {}

fixtures.project = {
  path = root .. '/example-project',
  some_existing_file = root .. '/example-project/src/foo.lean',
  some_nonexisting_file = root .. '/example-project/src/does_not_exist.lean',
  some_nested_existing_file = root .. '/example-project/src/bar/baz.lean',
  some_nested_nonexisting_file = root .. '/example-project/src/bar/does_not_exist.lean'
}

return fixtures
