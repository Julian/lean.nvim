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

---@param t CodeWithInfos
---@param sess Subsession
local function code_with_infos(t, sess)
  local div = html.Div:new({}, "", "code-with-infos")

  if t.text ~= nil then
    div:insert_div({}, t.text, "text")
  elseif t.append ~= nil then
    for _, s in ipairs(t.append) do
      div:insert_new_div(code_with_infos(s, sess))
    end
  elseif t.tag ~= nil then
    local info_with_ctx = t.tag[1].info

    local info_div = html.Div:new({event = {}}, "", "tooltip")

    local info_open = false

    local do_reset = function()
      info_div.divs = {}
      info_div:insert_div({}, "click for info!", "click-message")
      info_div.tags.event.clear = nil
      div:insert_new_tooltip(nil)
      info_open = false
      return true
    end

    ---@param info_popup InfoPopup
    local mk_tooltip = function(info_popup)
      local tooltip_div = html.Div:new()

      if info_popup.exprExplicit ~= nil then
        tooltip_div:insert_new_div(code_with_infos(info_popup.exprExplicit, sess))
        if info_popup.type ~= nil then
          tooltip_div:insert_div({}, ' :\n')
        end
      end

      if info_popup.type ~= nil then
        tooltip_div:insert_new_div(code_with_infos(info_popup.type, sess))
      end

      if info_popup.doc ~= nil then
        tooltip_div:insert_div({}, '\n\n')
        tooltip_div:insert_div({}, info_popup.doc) -- TODO: markdown
      end

      return tooltip_div
    end

    local do_open_all = function(tick, render_fn)
      if render_fn then
        info_div.divs = {}
        info_div:insert_div({}, "loading...", "loading-message")
        render_fn()
      end

      local info_popup, err = sess:infoToInteractive(info_with_ctx)
      if not tick:check() then
        do_reset()
        return true
      end

      if err then
        print("RPC ERROR:", vim.inspect(err.code), vim.inspect(err.message))
        do_reset()
        return false
      end

      info_div.divs = { mk_tooltip(info_popup) }
      info_div.tags.event.clear = do_reset
      div:insert_new_tooltip(info_div)
      info_open = true
      return true
    end

    local click = function(...)
      if info_open then
        return do_reset()
      else
        return do_open_all(...)
      end
    end

    do_reset()

    div.tags = {info_with_ctx = info_with_ctx, event = { click = click }}
    div.highlightable = true

    div:insert_new_div(code_with_infos(t.tag[2], sess))
  end

  return div
end

---@param goal InteractiveGoal | InteractiveTermGoal
---@param sess Subsession
local function interactive_goal(goal, sess)
  local div = html.Div:new({}, '', 'interactive-goal')

  if goal.userName ~= nil then
    div:insert_div({}, string.format('case %s\n', goal.userName))
  end

  for _, hyp in ipairs(goal.hyps) do
    div:start_div({hyp = hyp}, table.concat(hyp.names, ' ') .. ' : ', "hyp")

    div:insert_new_div(code_with_infos(hyp.type, sess))
    if hyp.val ~= nil then
      div:start_div({val = hyp.val}, " := ", "hyp_val")
      div:insert_new_div(code_with_infos(hyp.val, sess))
      div:end_div()
    end
    div:insert_div({}, "\n", "hypothesis-separator")

    div:end_div()
  end
  div:start_div({goal = goal.type}, '⊢ ', "goal")
  div:insert_new_div(code_with_infos(goal.type, sess))
  div:end_div()

  return div
end

---@param goal InteractiveGoals | nil
---@param sess Subsession
---@return Div
function components.interactive_goals(goal, sess)
  local div = html.Div:new({}, "", "interactive-goals")
  if goal == nil then return div end

  div:insert_div({},
    #goal.goals == 0 and H('goals accomplished 🎉') or
    #goal.goals == 1 and H('1 goal\n') or
    H(string.format('%d goals\n', #goal.goals)))

  for i, this_goal in ipairs(goal.goals) do
    if i ~= 1 then div:insert_div({}, '\n\n') end
    div:insert_new_div(interactive_goal(this_goal, sess))
  end

  return div
end

--- The current (term) goal state.
---@param goal InteractiveTermGoal
---@param sess Subsession
function components.interactive_term_goal(goal, sess)

  local div = html.Div:new({}, "", "interactive-term-goal")

  if not goal then return div end
  div:start_div({state = goal},
    H(string.format('expected type (%s)', range_to_string(goal.range))) .. '\n',
    "term-state")

  div:insert_new_div(interactive_goal(goal, sess))

  div:end_div()

  return div
end

--- Diagnostic information for the current line from the Lean server.
function components.diagnostics(bufnr, line)
  local div = html.Div:new({}, "")
  for _, diag in pairs(vim.lsp.diagnostic.get_line_diagnostics(bufnr, line)) do
    div:insert_div({}, "\n\n", "diagnostic-separator")
    div:insert_div({diag = diag},
        H(string.format('%s: %s:',
          range_to_string(diag.range),
          DiagnosticSeverity[diag.severity]:lower())) .. "\n" .. diag.message, "diagnostic")
  end
  return div
end

---@param t TaggedTextMsgEmbed
---@param sess Subsession
local function tagged_text_msg_embed(t, sess)
  local div = html.Div:new({}, "", "code-with-infos")

  if t.text ~= nil then
    div:insert_div({}, t.text, "text")
  elseif t.append ~= nil then
    for _, s in ipairs(t.append) do
      div:insert_new_div(tagged_text_msg_embed(s, sess))
    end
  elseif t.tag ~= nil then
    local embed = t.tag[1]
    if embed.expr ~= nil then
      return code_with_infos(embed.expr, sess)
    elseif embed.goal ~= nil then
      return interactive_goal(embed.goal, sess)
    elseif embed.lazyTrace ~= nil then
      local indent = embed.lazyTrace[1]
      local category = embed.lazyTrace[2]
      local msg_data = embed.lazyTrace[3]

      local is_open = false
      local expanded, expanded_err

      local click
      local function render()
        local header = html.Div:new({},
          string.format(is_open and '[%s] ▼' or '[%s] ▶', category))
        header.highlightable = true
        header.tags.event = { click = click }

        div.divs = {header}

        if is_open then
          if expanded then
            div:insert_new_div(tagged_text_msg_embed(expanded, sess))
          elseif expanded_err then
            div:insert_div({}, vim.inspect(expanded_err))
          else
            div:insert_div({}, ' loading...')
          end
        end
        return true
      end

      click = function(tick, render_fn)
        if is_open then
          is_open = false
        else
          is_open = true

          if not expanded then
            render()
            render_fn()

            expanded, expanded_err = sess:msgToInteractive(msg_data, indent)
            if not tick:check() then return true end
          end
        end
        render()
        return true
      end

      render()
    end
  end

  return div
end

--- Diagnostic information for the current line from the Lean server.
---@param line number
---@param diags InteractiveDiagnostic[]
---@param sess Subsession
function components.interactive_diagnostics(diags, line, sess)
  local div = html.Div:new({}, "")
  for _, diag in pairs(diags) do
    if diag.range.start.line == line then
      div:insert_div({}, "\n\n", "diagnostic-separator")
      div:insert_div({diag = diag},
          H(string.format('%s: %s:\n',
            range_to_string(diag.range),
            DiagnosticSeverity[diag.severity]:lower())), "diagnostic")
      div:insert_new_div(tagged_text_msg_embed(diag.message, sess))
    end
  end
  return div
end

return components
