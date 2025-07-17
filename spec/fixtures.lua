local this_file = debug.getinfo(1).source:match '@(.*)$'

local fixtures_root = vim.fs.joinpath(vim.fs.dirname(this_file), 'fixtures')
local indent = vim.fs.joinpath(fixtures_root, 'indent')
local widgets = vim.fs.joinpath(fixtures_root, 'widgets')
local projects = vim.fs.joinpath(fixtures_root, 'projects')

---A sample Lean project used in tests.
---@class Project
---@field private _root string
local Project = {}
Project.__index = Project

---Represent a new Lean project.
---@param name string
function Project:new(name)
  local root = vim.fs.normalize(vim.fs.joinpath(projects, name))
  assert.is.truthy(vim.uv.fs_stat(root))
  return setmetatable({ _root = root }, self)
end

---A child path within this project.
---@param name string
function Project:child(name)
  return vim.fs.joinpath(self._root, name)
end

local example = Project:new 'Example'
local with_widgets = Project:new 'WithWidgets'

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
  widgets = widgets,

  example = example,
  with_widgets = with_widgets,

  project = {
    root = example._root,

    some_existing_file = example:child 'Example.lean',
    some_nonexisting_file = example:child 'DoesNotExist.lean',
    some_nested_existing_file = example:child 'Example/Squares.lean',
    some_nested_nonexisting_file = example:child 'Example/DoesNotExist.lean',
  },
}

function fixtures.project.child(name)
  return example:child(name)
end

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

assert.is.truthy(vim.uv.fs_stat(indent))
assert.is.truthy(vim.uv.fs_stat(widgets))

return fixtures
