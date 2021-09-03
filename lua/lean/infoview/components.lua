---@brief [[
--- Infoview components which can be assembled to show various information
--- about the current Lean module or state.
---@brief ]]

---@tag lean.infoview.components

local DiagnosticSeverity = vim.lsp.protocol.DiagnosticSeverity
local components = {}

local html = require"lean.html"

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

--- The current (term) goal state.
---@param goal InteractiveTermGoal
---@param sess Subsession
function components.interactive_term_goal(goal, sess)
  ---@param t CodeWithInfos
  local function code_with_infos(t)
    local div = html.Div:new({}, "", "code-with-infos")

    if t.text ~= nil then
      div:insert_div({}, t.text, "text")
    elseif t.append ~= nil then
      for _, s in ipairs(t.append) do
        div:insert_new_div(code_with_infos(s))
      end
    elseif t.tag ~= nil then
      local info_with_ctx = t.tag[1].info

      local info_div = html.Div:new({event = {}}, "", "tooltip")

      local info_open = false
      local tick = 0
      local last_call

      local function new_tick()
        tick = tick + 1
        return tick
      end

      local reset = function(_)
        info_div.divs = {}
        info_div.tags.event.close = nil
        info_open = false
        return true
      end

      local undo_wrap = function(call)
        return function()
          reset()
          local this_tick = new_tick()
          local success = call(this_tick)
          if this_tick ~= tick then return end

          local orig_last_call = last_call
          last_call = call

          return function()
            reset()
            last_call = orig_last_call
            return orig_last_call(new_tick())
          end, success
        end
      end

      local do_reset = undo_wrap(function() return true end)

      last_call = reset

      local do_open_all = undo_wrap(function(this_tick)
        local info_popup, err = sess:infoToInteractive(info_with_ctx)
        if this_tick ~= tick then return false end

        if err then print("RPC ERROR:", vim.inspect(err.code), vim.inspect(err.message)) return false end

        info_div:insert_div({}, "→[", "tooltip-prefix", function() return div.hlgroup(div) or "leanInfoTooltip" end)
        local keys = {}
        for key, _ in pairs(info_popup) do
          table.insert(keys, key)
        end
        table.sort(keys)
        for _, key in ipairs(keys) do
          info_div:start_div({}, "", "info-item")
          info_div:insert_div({}, '\n' .. key , "info-item-prefix", "leanInfoButton")
          info_div:insert_div({}, ': ', "separator")
          info_div:insert_new_div(code_with_infos(info_popup[key]))
          info_div:end_div()
        end
        info_div:insert_div({}, "]", "tooltip-suffix", function() return div.hlgroup(div) or "leanInfoTooltip" end)
        info_div.tags.event.close = do_reset
        info_open = true
        return true
      end)

      local click = function()
        if info_open then
          return do_reset()
        else
          return do_open_all()
        end
      end

      div.tags = {info_with_ctx = info_with_ctx, event = { click = click }}
      div.hlgroup = html.util.highlight_check

      div:insert_new_div(code_with_infos(t.tag[2]))

      div:insert_new_div(info_div)
    end

    return div
  end

  local div = html.Div:new({}, "", "interactive-term-goal")

  if not goal then return div end
  div:start_div({state = goal},
    H(string.format('expected type (%s)', range_to_string(goal.range))) .. '\n',
    "term-state")

  for _, hyp in ipairs(goal.hyps) do
    div:start_div({hyp = hyp}, table.concat(hyp.names, ' ') .. ' : ', "hyp")

    div:insert_new_div(code_with_infos(hyp.type))
    if hyp.val ~= nil then
      div:start_div({val = hyp.val}, " := ", "hyp_val")
      div:insert_new_div(code_with_infos(hyp.val))
      div:end_div()
    end
    div:insert_div({}, "\n", "hypothesis-separator")

    div:end_div()
  end
  div:start_div({goal = goal.type}, '⊢ ', "goal")
  div:insert_new_div(code_with_infos(goal.type))
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
