local this_file = debug.getinfo(1).source:match("@(.*)$")
local root = vim.fn.fnamemodify(this_file, ":p:h") .. "/fixtures"

return {
  root = root,
  lean_project = {
    path = root .. '/example-lean4-project',
    some_existing_file = root .. '/example-lean4-project/Test.lean',
    some_nonexisting_file = root .. '/example-lean4-project/DoesNotExist.lean',
    some_nested_existing_file = root .. '/example-lean4-project/Test/Test1.lean',
    some_nested_nonexisting_file = root .. '/example-lean4-project/Test/DoesNotExist.lean',
  },
  lean3_project = {
    path = root .. '/example-lean3-project',
    some_existing_file = root .. '/example-lean3-project/src/foo.lean',
    some_nonexisting_file = root .. '/example-lean3-project/src/does_not_exist.lean',
    some_nested_existing_file = root .. '/example-lean3-project/src/bar/baz.lean',
    some_nested_nonexisting_file = root .. '/example-lean3-project/src/bar/does_not_exist.lean'
  },
}
