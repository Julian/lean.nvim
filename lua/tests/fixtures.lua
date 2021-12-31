local this_file = debug.getinfo(1).source:match("@(.*)$")
local root = vim.fn.fnamemodify(this_file, ":p:h") .. "/fixtures"

local lean_project = {
  path = root .. '/example-lean4-project',
  some_existing_file = root .. '/example-lean4-project/Test.lean',
  some_nonexisting_file = root .. '/example-lean4-project/DoesNotExist.lean',
  some_nested_existing_file = root .. '/example-lean4-project/Test/Squares.lean',
  some_nested_nonexisting_file = root .. '/example-lean4-project/Test/DoesNotExist.lean',
}

local lean3_project = {
  path = root .. '/example-lean3-project',
  some_existing_file = root .. '/example-lean3-project/src/foo.lean',
  some_nonexisting_file = root .. '/example-lean3-project/src/does_not_exist.lean',
  some_nested_existing_file = root .. '/example-lean3-project/src/bar/baz.lean',
  some_nested_nonexisting_file = root .. '/example-lean3-project/src/bar/does_not_exist.lean'
}

for _, project in pairs({lean_project, lean3_project}) do
  project.files_it = {pairs{
    ["existing"] = project.some_existing_file,
    ["nested existing"] = project.some_nested_existing_file,
    ["nonexisting"] = project.some_nonexisting_file,
    ["nested nonexisting"] = project.some_nested_nonexisting_file
  }}
end


return {root = root, lean_project = lean_project, lean3_project = lean3_project}
