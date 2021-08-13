---@brief [[
--- Infoview components which can be assembled to show various information
--- about the current Lean module or state.
---@brief ]]

---@tag lean.infoview.components

local DiagnosticSeverity = vim.lsp.protocol.DiagnosticSeverity
local components = {}


--- Format a heading.
local function H(contents)
  return string.format('▶ %s', contents)
end

--- Convert an LSP range to a human-readable, (1,1)-indexed string.
---
--- The (1, 1) indexing is to match the interface used interactively for
--- `gg` and `|`.
local function range_to_string(range)
  return string.format('%d:%d-%d:%d',
    range["start"].line + 1,
    range["start"].character + 1,
    range["end"].line + 1,
    range["end"].character + 1)
end

--- The current (tactic) goal state.
---@param goal table: a Lean4 `plainGoal` LSP response
function components.goal(goal)
  if type(goal) ~= "table" or not goal.goals then return {} end

  local lines = {
    #goal.goals == 0 and H('goals accomplished 🎉') or
    #goal.goals == 1 and H('1 goal') or
    H(string.format('%d goals', #goal.goals))
  }

  for _, each in pairs(goal.goals) do
    vim.list_extend(lines, {''})
    vim.list_extend(lines, vim.split(each, '\n', true))
  end

  return lines
end

--- The current (term) goal state.
---@param term_goal table: a Lean4 `plainTermGoal` LSP response
function components.term_goal(term_goal)
  if type(term_goal) ~= "table" or not term_goal.goal then return {} end

  local lines = {
    H(string.format('expected type (%s)', range_to_string(term_goal.range)))
  }
  vim.list_extend(lines, vim.split(term_goal.goal, '\n', true))

  return lines
end

--- Diagnostic information for the current line from the Lean server.
function components.diagnostics(bufnr, line)
  local lines = {}

  for _, diag in pairs(vim.lsp.diagnostic.get_line_diagnostics(bufnr, line)) do
    vim.list_extend(lines,
      {'',
        H(string.format('%s: %s:',
          range_to_string(diag.range),
          DiagnosticSeverity[diag.severity]:lower()))})
    vim.list_extend(lines, vim.split(diag.message, '\n', true))
  end

  return lines
end

return components
