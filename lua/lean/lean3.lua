local find_project_root = require('lspconfig.util').root_pattern('leanpkg.toml')

local components = require('lean.infoview.components')
local subprocess_check_output = require('lean._util').subprocess_check_output

local lean3 = {}

-- Ideally this obviously would use a TOML parser but yeah choosing to
-- do nasty things and not add the dependency for now.
local _PROJECT_MARKER = '.*lean_version.*\".*:3.*'
local _STANDARD_LIBRARY_PATHS = '.*/lean--3.+/lib/'

-- Split a Lean 3 server response on goals.
--
-- Looks for ⊢, but ignores indented following lines for multi-line
-- goals.
--
-- Really this should also make sure ⊢ is on the
-- start of the line via \_^, but this returns nil:
-- `vim.regex('\\_^b'):match_str("foo\nbar\nbaz\n")` and I don't
-- understand why; perhaps it's a neovim bug. Lua's string.gmatch also
-- seems not powerful enough to do this.
--
-- Important properties of the number 2:
--
--    * the only even prime number
--    * the number of problems you have after using regex to solve a problem
local _GOAL_MARKER = vim.regex('⊢ .\\{-}\n\\(\\s\\+.\\{-}\\(\n\\|$\\)\\)*\\zs')

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

--- Convert a Lean 3 response to one that the Lean 4 server would respond with.
local function upconvert_lsp_goal_to_lean4(response)
  local goals = {}
  for _, contents in ipairs(response.contents) do
    if contents.language == 'lean' and contents.value ~= 'no goals' then
      if contents.value:match('⊢') then
        -- strip 'N goals' from the front (which is present for multiple goals)
        local rest_of_goals = contents.value:gsub('^%d+ goals?\n', '')

        repeat
          local end_of_goal = _GOAL_MARKER:match_str(rest_of_goals)
          table.insert(goals, vim.trim(rest_of_goals:sub(1, end_of_goal)))
          if not end_of_goal then break end
          rest_of_goals = rest_of_goals:sub(end_of_goal + 1)
        until rest_of_goals == ""
      end
    end
  end
  return { goals = goals }
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

function lean3.update_infoview(set_lines)
  local params = vim.lsp.util.make_position_params()
  return vim.lsp.buf_request(0, "textDocument/hover", params, function(_, _, result)
    local lines = {}
    if result and type(result) == "table" and not vim.tbl_isempty(result.contents) then
      vim.list_extend(
        lines,
        components.goal(upconvert_lsp_goal_to_lean4(result)))
    end
    vim.list_extend(lines, components.diagnostics())

    set_lines(lines)
  end)
end

return lean3
