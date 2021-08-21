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
---@param div table: the current div
---@param goal table: a Lean4 `plainGoal` LSP response
function components.goal(div, goal)
  if type(goal) ~= "table" or not goal.goals then return end

  div:start_div({goals = goal.goals}, #goal.goals == 0 and H('goals accomplished 🎉') or
    #goal.goals == 1 and H('1 goal') or
    H(string.format('%d goals', #goal.goals)), "plain-goals")

  for _, this_goal in pairs(goal.goals) do
    div:start_div({goal = this_goal}, "\n" .. this_goal, "plain-goal")
    div:end_div()
  end

  div:end_div()
end

--- The current (term) goal state.
---@param div table: the current div
---@param term_goal table: a Lean4 `plainTermGoal` LSP response
function components.term_goal(div, term_goal)
  if type(term_goal) ~= "table" or not term_goal.goal then return end

  div:start_div({term_goal = term_goal},
    H(string.format('expected type (%s)', range_to_string(term_goal.range)) .. "\n" .. term_goal.goal),
    "term-goal")
  div:end_div()
end

--- Diagnostic information for the current line from the Lean server.
function components.diagnostics(div, bufnr, line)
  for _, diag in pairs(vim.lsp.diagnostic.get_line_diagnostics(bufnr, line)) do
    div:start_div({}, "\n", "diagnostic-separator")
    div:end_div()
    div:start_div({diag = diag},
        H(string.format('%s: %s:',
          range_to_string(diag.range),
          DiagnosticSeverity[diag.severity]:lower())) .. "\n" .. diag.message, "diagnostic")
    div:end_div()
  end
end

return components
