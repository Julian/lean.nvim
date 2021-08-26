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
---@param range LspRange
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
    H(string.format('%d goals', #goal.goals)))

  for _, this_goal in pairs(goal.goals) do
    div:start_div({goal = this_goal}, "\n" .. this_goal)
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
    H(string.format('expected type (%s)', range_to_string(term_goal.range)) .. "\n" .. term_goal.goal))
  div:end_div()
end

---@param div Div
---@param t CodeWithInfos
function components.code_with_infos(div, t)
  if t.text ~= nil then
    div:start_div({t = t}, t.text, "text")
    div:end_div()
  elseif t.append ~= nil then
    for _, s in ipairs(t.append) do
      components.code_with_infos(div, s)
    end
  elseif t.tag ~= nil then
    div:start_div({tag = t.tag}, nil, "tag")
    components.code_with_infos(div, t.tag[2])
    div:end_div()
  end
end

--- The current (term) goal state.
---@param div table: the current div
---@param goal InteractiveTermGoal
function components.interactive_term_goal(div, goal)
  if not goal then return end

  div:start_div({state = goal},
    H(string.format('expected type (%s)', range_to_string(goal.range))) .. '\n',
    "term_state")

  for _, hyp in ipairs(goal.hyps) do
    div:start_div({hyp = hyp}, table.concat(hyp.names, ' ') .. ' : ', "hyp")
    components.code_with_infos(div, hyp.type)
    if hyp.val ~= nil then
      div:start_div({val = hyp.val}, " := ", "hyp_val")
      components.code_with_infos(div, hyp.val)
      div:end_div()
    end
    div:start_div({}, "\n")
    div:end_div()
    div:end_div()
  end
  div:start_div({goal = goal.type}, '⊢ ', "goal")
  components.code_with_infos(div, goal.type)
  div:end_div()
  div:end_div()
end


--- Diagnostic information for the current line from the Lean server.
function components.diagnostics(div)
  for _, diag in pairs(vim.lsp.diagnostic.get_line_diagnostics()) do
    div:start_div({diag = diag},
        H(string.format('%s: %s:',
          range_to_string(diag.range),
          DiagnosticSeverity[diag.severity]:lower())) .. "\n" .. diag.message)
    div:end_div()
  end
end

return components
