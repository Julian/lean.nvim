---@brief [[
--- Infoview components which can be assembled to show various information
--- about the current Lean module or state.
---@brief ]]

---@tag lean.infoview.components

local DiagnosticSeverity = vim.lsp.protocol.DiagnosticSeverity
local components = {}

local html = require"lean.html"

local a = require"plenary.async"

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
  local div = html.Div:new({}, "", "plain-goals")
  if type(goal) ~= "table" or not goal.goals then return div end

  div:start_div({goals = goal.goals}, #goal.goals == 0 and H('goals accomplished 🎉') or
    #goal.goals == 1 and H('1 goal') or
    H(string.format('%d goals', #goal.goals)), "plain-goals-list")

  for _, this_goal in pairs(goal.goals) do
    div:insert_div({goal = this_goal}, "\n" .. this_goal, "plain-goal")
  end

  div:end_div()
  return div
end

--- The current (term) goal state.
---@param term_goal table: a Lean4 `plainTermGoal` LSP response
function components.term_goal(term_goal)
  local div = html.Div:new({}, "", "plain-term-goal")
  if type(term_goal) ~= "table" or not term_goal.goal then return div end

  div:insert_div({term_goal = term_goal},
    H(string.format('expected type (%s)', range_to_string(term_goal.range)) .. "\n" .. term_goal.goal),
    "term-goal")
  return div
end

---@param t CodeWithInfos
---@param pin Pin
function components.code_with_infos(t, pin)
  local div = html.Div:new({}, "", "code-with-infos")

  if t.text ~= nil then
    div:insert_div({}, t.text, "text")
  elseif t.append ~= nil then
    for _, s in ipairs(t.append) do
      div:insert_new_div(components.code_with_infos(s, pin))
    end
  elseif t.tag ~= nil then
    local info_with_ctx = t.tag[1].info

    local info_div = html.Div:new()

    local prefix_div = html.Div:new()
    local type_div = html.Div:new()
    local expr_div = html.Div:new()
    local doc_div = html.Div:new()
    local suffix_div = html.Div:new()

    info_div:insert_new_div(prefix_div)
    info_div:insert_new_div(type_div)
    info_div:insert_new_div(expr_div)
    info_div:insert_new_div(doc_div)
    info_div:insert_new_div(suffix_div)

    local _click = function()
      local info_popup, err = pin.sess:infoToInteractive(info_with_ctx)
      if err then print("RPC ERROR:", vim.inspect(err.code), vim.inspect(err.message)) return end

      local tt_open = false

      local type_open = #type_div.divs > 0
      type_div.divs = {}
      if not type_open and info_popup['type'] ~= nil then
        type_div:insert_div({}, '\ntype', "type-prefix", "leanInfoButton")
        type_div:insert_div({}, ': ', "separator", "")
        type_div:insert_new_div(components.code_with_infos(info_popup['type'], pin))
        tt_open = true
      end

      local expr_open = #expr_div.divs > 0
      expr_div.divs = {}
      if not expr_open and info_popup.exprExplicit ~= nil then
        expr_div:insert_div({}, '\nexpr explicit', "exprExplicit-prefix", "leanInfoButton")
        expr_div:insert_div({}, ': ', "separator", "", "Normal")
        expr_div:insert_new_div(components.code_with_infos(info_popup.exprExplicit, pin))
        tt_open = true
      end

      local doc_open = #doc_div.divs > 0
      doc_div.divs = {}
      if not doc_open and info_popup.doc ~= nil then
        doc_div:insert_div({}, '\n' .. info_popup.doc, 'docstring') -- TODO: render markdown
        tt_open = true
      end

      prefix_div.divs = {}
      suffix_div.divs = {}

      if tt_open == true then
        prefix_div:insert_div({}, "→[", "tooltip", function() return div.hlgroup(div) or "leanInfoTooltip" end)
        suffix_div:insert_div({}, "]", "tooltip", function() return div.hlgroup(div) or "leanInfoTooltip" end)
      end

      pin:render_parents()
    end

    div.tags = {info_with_ctx = info_with_ctx, event = { _click = _click, click = a.void(_click) } }
    div.hlgroup = html.util.highlight_check

    div:insert_new_div(components.code_with_infos(t.tag[2], pin))

    div:insert_new_div(info_div)
  end

  return div
end

--- The current (term) goal state.
---@param goal InteractiveTermGoal
---@param pin Pin
function components.interactive_term_goal(goal, pin)
  local div = html.Div:new({}, "", "interactive-term-goal")

  if not goal then return div end
  div:start_div({state = goal},
    H(string.format('expected type (%s)', range_to_string(goal.range))) .. '\n',
    "term-state")

  for _, hyp in ipairs(goal.hyps) do
    div:start_div({hyp = hyp}, table.concat(hyp.names, ' ') .. ' : ', "hyp")

    div:insert_new_div(components.code_with_infos(hyp.type, pin))
    if hyp.val ~= nil then
      div:start_div({val = hyp.val}, " := ", "hyp_val")
      div:insert_new_div(components.code_with_infos(hyp.val, pin))
      div:end_div()
    end
    div:insert_div({}, "\n", "hypothesis-separator")

    div:end_div()
  end
  div:start_div({goal = goal.type}, '⊢ ', "goal")
  div:insert_new_div(components.code_with_infos(goal.type, pin))
  div:end_div()

  div:end_div()

  return div
end

--- Diagnostic information for the current line from the Lean server.
function components.diagnostics(bufnr, line)
  local div = html.Div:new({}, "")
  for _, diag in pairs(vim.lsp.diagnostic.get_line_diagnostics(bufnr, line)) do
    div:insert_div({}, "\n", "diagnostic-separator")
    div:insert_div({diag = diag},
        H(string.format('%s: %s:',
          range_to_string(diag.range),
          DiagnosticSeverity[diag.severity]:lower())) .. "\n" .. diag.message, "diagnostic")
  end
  return div
end

return components
