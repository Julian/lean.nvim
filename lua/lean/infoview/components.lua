---@brief [[
--- Infoview components which can be assembled to show various information
--- about the current Lean module or state.
---@brief ]]

---@tag lean.infoview.components

local DiagnosticSeverity = vim.lsp.protocol.DiagnosticSeverity

local Element = require('lean.widgets').Element

local components = {}

--- Format a heading.
local function H(contents)
  return string.format('▶ %s', contents)
end

---@param text string?
local function mk_tooltip_element(text)
  local element = Element:new{ text = text }
  local stop_bubbling = function() end
  element.events = {
    click = stop_bubbling,
    mouse_enter = stop_bubbling,
    mouse_leave = stop_bubbling,
  }
  return element
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
---@return Element[]
function components.goal(goal)
  if type(goal) ~= "table" or not goal.goals then return {} end

  local element = Element:new{ name = "plain-goals" }

  local goals_list = Element:new{
    text = #goal.goals == 0 and H('goals accomplished 🎉')
      or #goal.goals == 1 and H('1 goal')
      or H(string.format('%d goals', #goal.goals)),
    name = "plain-goals-list"
  }
  element:add_child(goals_list)

  for _, this_goal in pairs(goal.goals) do
    goals_list:add_child(Element:new{ text = '\n' .. this_goal, name = 'plain-goal' })
  end

  return { element }
end

--- The current (term) goal state.
---@param term_goal table: a Lean4 `plainTermGoal` LSP response
---@return Element[]
function components.term_goal(term_goal)
  if type(term_goal) ~= "table" or not term_goal.goal then return {} end

  return {
    Element:new{
      text = H(string.format('expected type (%s)', range_to_string(term_goal.range)) .. "\n" .. term_goal.goal),
      name = 'term-goal'
    }
  }
end

---@param t CodeWithInfos
---@param sess Subsession
local function code_with_infos(t, sess)
  local element = Element:new{ name = 'code-with-infos' }

  if t.text ~= nil then
    element:add_child(Element:new{ text = t.text, name = "text" })
  elseif t.append ~= nil then
    for _, s in ipairs(t.append) do
      element:add_child(code_with_infos(s, sess))
    end
  elseif t.tag ~= nil then
    local info_with_ctx = t.tag[1].info

    local info_open = false

    local do_reset = function(ctx)
      info_open = false
      element:add_tooltip(nil)
      ctx.rehover()
    end

    ---@param info_popup InfoPopup
    local mk_tooltip = function(info_popup)
      local tooltip_element = mk_tooltip_element()

      if info_popup.exprExplicit ~= nil then
        tooltip_element:add_child(code_with_infos(info_popup.exprExplicit, sess))
        if info_popup.type ~= nil then
          tooltip_element:add_child(Element:new{ text = ' :\n' })
        end
      end

      if info_popup.type ~= nil then
        tooltip_element:add_child(code_with_infos(info_popup.type, sess))
      end

      if info_popup.doc ~= nil then
        tooltip_element:add_child(Element:new{ text = '\n\n' })
        tooltip_element:add_child(Element:new{ text = info_popup.doc }) -- TODO: markdown
      end

      return tooltip_element
    end

    local do_open_all = function(ctx)
      local info_popup, err = sess:infoToInteractive(info_with_ctx)

      local tooltip
      if err then
        tooltip = mk_tooltip_element(vim.inspect(err))
      else
        tooltip = mk_tooltip(info_popup)
        info_open = true
      end

      element:add_tooltip(tooltip)
      ctx.rehover()
    end

    local click = function(ctx)
      if info_open then
        return do_reset(ctx)
      else
        return do_open_all(ctx)
      end
    end

    element.events = {
      click = click,
      clear = function(ctx) if info_open then do_reset(ctx) end end,
    }
    element.highlightable = true

    element:add_child(code_with_infos(t.tag[2], sess))
  end

  return element
end

---@param goal InteractiveGoal | InteractiveTermGoal
---@param sess Subsession
local function interactive_goal(goal, sess)
  local element = Element:new{ name = 'interactive-goal' }

  if goal.userName ~= nil then
    element:add_child(Element:new{ text = string.format('case %s\n', goal.userName) })
  end

  for _, hyp in ipairs(goal.hyps) do
    local hyp_element = Element:new{
      text = table.concat(hyp.names, ' ') .. ' : ',
      name = "hyp",
      children = { code_with_infos(hyp.type, sess) }
    }
    element:add_child(hyp_element)

    if hyp.val ~= nil then
      hyp_element:add_child(
        Element:new{
          text = " := ",
          name = 'hyp_val',
          children = { code_with_infos(hyp.val, sess) }
        }
      )
    end
    hyp_element:add_child(Element:new{ text = "\n", name = 'hypothesis-separator' })
  end

  element:add_child(
    Element:new{
      text = '⊢ ',
      name = 'goal',
      children = { code_with_infos(goal.type, sess) }
    }
  )
  return element
end

---@param goal InteractiveGoals | nil
---@param sess Subsession
---@return Element[]
function components.interactive_goals(goal, sess)
  if goal == nil then return {} end

  local element = Element:new{
    name = 'interactive-goals',
    children = {
      Element:new{
        text = #goal.goals == 0 and H('goals accomplished 🎉')
          or #goal.goals == 1 and H('1 goal\n')
          or H(string.format('%d goals\n', #goal.goals))
      }
    }
  }

  for i, this_goal in ipairs(goal.goals) do
    if i ~= 1 then element:add_child(Element:new{ text = '\n\n' }) end
    element:add_child(interactive_goal(this_goal, sess))
  end

  return { element }
end

--- The current (term) goal state.
---@param goal InteractiveTermGoal
---@param sess Subsession
---@return Element[]
function components.interactive_term_goal(goal, sess)
  if not goal then return {} end

  local element = Element:new{ name = 'interactive-term-goal' }

  local term_state_element = Element:new{
    text = H(string.format('expected type (%s)', range_to_string(goal.range))) .. '\n',
    name = 'term-state'
  }
  term_state_element:add_child(interactive_goal(goal, sess))
  element:add_child(term_state_element)

  return { element }
end

--- Diagnostic information for the current line from the Lean server.
---@return Element[]
function components.diagnostics(bufnr, line)
  local elements = {}
  for _, diag in pairs(vim.lsp.diagnostic.get_line_diagnostics(bufnr, line)) do
    table.insert(
      elements, Element:new{
        text = H(string.format('%s: %s:',
          range_to_string(diag.range),
          DiagnosticSeverity[diag.severity]:lower())) .. "\n" .. diag.message,
        name = 'diagnostic'
      }
    )
  end
  return elements
end

---@param t TaggedTextMsgEmbed
---@param sess Subsession
local function tagged_text_msg_embed(t, sess)
  local element = Element:new{ name = 'code-with-infos' }

  if t.text ~= nil then
    element.text = t.text
  elseif t.append ~= nil then
    for _, s in ipairs(t.append) do
      element:add_child(tagged_text_msg_embed(s, sess))
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
        local header = Element:new{ text = string.format(is_open and '[%s] ▼' or '[%s] ▶', category) }
        header.highlightable = true
        header.events = { click = click }

        element:set_children{ header }

        if is_open then
          if expanded then
            element:add_child(tagged_text_msg_embed(expanded, sess))
          elseif expanded_err then
            element:add_child(Element:new{ text = vim.inspect(expanded_err) })
          end
        end
        return true
      end

      click = function(ctx)
        if is_open then
          is_open = false
        else
          is_open = true

          if not expanded then
            expanded, expanded_err = sess:msgToInteractive(msg_data, indent)
          end
        end
        render()
        ctx.rerender()
      end

      render()
    end
  end

  return element
end

--- Diagnostic information for the current line from the Lean server.
---@param line number
---@param diags InteractiveDiagnostic[]
---@param sess Subsession
---@return Element[]
function components.interactive_diagnostics(diags, line, sess)
  local elements = {}
  for _, diag in pairs(diags) do
    if diag.range.start.line == line then
      local element = Element:new{
          text = H(string.format('%s: %s:\n',
            range_to_string(diag.range),
            DiagnosticSeverity[diag.severity]:lower())),
          name = 'diagnostic'
      }
      element:add_child(tagged_text_msg_embed(diag.message, sess))
      table.insert(elements, element)
    end
  end
  return elements
end

return components
