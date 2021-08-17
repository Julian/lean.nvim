local find_project_root = require('lspconfig.util').root_pattern('leanpkg.toml')

local components = require('lean.infoview.components')
local subprocess_check_output = require('lean._util').subprocess_check_output

local a = require('plenary.async')

local lean3 = {}

-- Ideally this obviously would use a TOML parser but yeah choosing to
-- do nasty things and not add the dependency for now.
local _PROJECT_MARKER = '.*lean_version.*\".*:3.*'
local _STANDARD_LIBRARY_PATHS = '.*/lean--3.+/lib/'

--- Detect whether the current buffer is a Lean 3 file.
function lean3.__detect()
  local path = vim.api.nvim_buf_get_name(0)
  if path:match(_STANDARD_LIBRARY_PATHS) then return true end

  local project_root = find_project_root(path)
  if project_root then
    local result = vim.fn.readfile(project_root .. '/leanpkg.toml')
    for _, line in ipairs(result) do
      if line:match(_PROJECT_MARKER) then return true end
    end
  end

  return false
end

--- Return the current Lean 3 search path.
---
--- Includes both the Lean 3 core libraries as well as project-specific
--- directories (i.e. equivalent to what is reported by `lean --path`).
function lean3.__current_search_paths()
  local root = vim.lsp.buf.list_workspace_folders()[1]
  local result = subprocess_check_output{command = "lean", args = {"--path"}, cwd = root }
  return vim.fn.json_decode(table.concat(result, '')).path
end

local buf_request = a.wrap(vim.lsp.buf_request, 4)
function lean3.update_infoview()
  local _, _, result = buf_request(0, "$/lean/plainGoal", vim.lsp.util.make_position_params())
  local lines = {}
  if result and type(result) == "table" then
    vim.list_extend(lines, components.goal(result))
  end
  return vim.list_extend(lines, components.diagnostics())
end

return lean3
