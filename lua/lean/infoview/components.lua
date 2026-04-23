---@brief [[
--- Infoview components which can be assembled to show various information
--- about the current Lean module or state.
---@brief ]]

---@tag lean.infoview.components

local range_to_string = require('std.lsp').range_to_string

local Element = require('lean.tui').Element
local Locations = require 'lean.infoview.locations'
local interactive_diagnostic = require 'lean.widget.interactive_diagnostic'
local TaggedTextMsgEmbed = interactive_diagnostic.TaggedTextMsgEmbed
local TaggedTextHighlightedMsgEmbed = interactive_diagnostic.TaggedTextHighlightedMsgEmbed
local config = require 'lean.config'
local diagnostic = require 'lean.diagnostic'
local goals = require 'lean.goals'
local interactive_goal = require 'lean.widget.interactive_goal'
local lsp = require 'lean.lsp'
local widgets = require 'lean.widgets'

local components = {
  LSP_HAS_DIED = Element:new {
    text = '🪦 The Lean language server is dead.',
    hlgroups = { 'DiagnosticError' },
  },
  NO_INFO = Element:new { text = 'No info.', name = 'no-info' },
  PROCESSING = Element:new { text = 'Processing file...', name = 'processing' },
  EMPTY = Element.EMPTY,
}

---Diagnostic information for the current line from the Lean server.
---@param line number
---@param diags InteractiveDiagnostic[]
---@param sess ReconnectingSubsession
---@return Element[]
function components.interactive_diagnostics(diags, line, sess)
  local markers = config().infoview.severity_markers

  return vim
    .iter(diags)
    ---@param each InteractiveDiagnostic
    :map(function(each)
      if each.range.start.line ~= line then
        return
      end

      local range = diagnostic.range_of(each)
      local element = Element:new {
        text = ('▼ %s: %s'):format(range_to_string(range), markers[each.severity]),
        name = 'diagnostic',
        children = { TaggedTextMsgEmbed(each.message, sess) },
      }
      if interactive_diagnostic.is_trace_message(each.message) then
        local message = each.message
        element.events.trace_search = function(ctx, query)
          if query == '' then
            element:set_children { TaggedTextMsgEmbed(message, sess) }
          else
            local result, err = sess:highlightMatches(query, message)
            if err then
              vim.notify(('Trace search error: %s'):format(vim.inspect(err)), vim.log.levels.ERROR)
              return
            end
            element:set_children { TaggedTextHighlightedMsgEmbed(result, sess) }
          end
          ctx.rerender()
        end
      end
      return element
    end)
    :totable()
end

---Wrap raw goal children with multi-goal headers and accomplished/no-goals titles.
---@param params lsp.TextDocumentPositionParams
---@param goal string[]|InteractiveGoal[]|nil the list of goals
---@param children Element[]? rendered goal elements
---@return Element[]? wrapped
local function wrap_goals(params, goal, children)
  if goal and #goal > 1 then
    children = {
      Element:foldable {
        title = Element.title(('%d goals'):format(#goal), 'leanInfoMultipleGoals'),
        body = children,
        margin = 1,
      },
    }
  end

  local title
  if lsp.goals_accomplished_at(params) then
    title = 'Goals accomplished 🎉'
  elseif goal and #goal == 0 then -- between goals / Lean <4.19 with no markers
    title = vim.g.lean_no_goals_message or 'No goals.'
  else
    return children
  end

  return {
    Element:titled {
      title = Element.title(title, 'leanInfoGoals'),
      body = children,
    },
  }
end

---@param sess ReconnectingSubsession
---@param view_options InfoviewViewOptions
---@return Element[]? goal
---@return LspError? error
function components.goal_at(sess, view_options)
  local goal, err = goals.at(sess)
  if err then
    return nil, err
  end
  local children = goal and interactive_goal.Goals(goal, sess, Locations.at(sess.pos), view_options)
  return wrap_goals(sess.pos, goal, children), err
end

---@param params lsp.TextDocumentPositionParams
---@return Element[]? goal
---@return LspError? error
function components.plain_goal_at(params)
  local plain = require 'lean.infoview.plain'
  local goal, children = plain.goal(params)
  return wrap_goals(params, goal, children)
end

---@param sess ReconnectingSubsession
---@param view_options InfoviewViewOptions
---@return Element[]?
---@return LspError?
function components.term_goal_at(sess, view_options)
  local term_goal, err = sess:getInteractiveTermGoal()
  term_goal = term_goal and interactive_goal.interactive_term_goal(term_goal, sess, view_options)
  return term_goal, err
end

---Retrieve the interactive diagnostics at the given line.
---
---Filters out silent diagnostics which we show elsewhere.
---@param sess ReconnectingSubsession
---@param line number
---@return DiagnosticWith<TaggedText.MsgEmbed>[]
---@return LspError
local function interactive_diagnostics_for(sess, line)
  ---@type LineRange
  local range = { start = line, ['end'] = line + 1 }
  local diagnostics, err = sess:getInteractiveDiagnostics(range)
  if err then
    return {}, err
  end
  return diagnostics, err
end

---@param sess ReconnectingSubsession
---@return Element[]?
---@return LspError?
function components.diagnostics_at(sess)
  local line = sess.pos.position.line
  local diagnostics, err = interactive_diagnostics_for(sess, line)
  if err then
    return interactive_goal.diagnostics(sess.pos), err
  end

  ---We filter goals accomplished diagnostics from showing in the infoview, as
  ---they'll be indicated at the top.
  ---@param each DiagnosticWith<TaggedText.MsgEmbed>
  local filtered = vim.iter(diagnostics):filter(function(each)
    return not diagnostic.is_goals_accomplished(each)
  end)
  return components.interactive_diagnostics(filtered, line, sess), err
end

---@param sess ReconnectingSubsession
---@return Element[]? widgets
---@return LspError? error
function components.user_widgets_at(sess)
  local response, err = sess:getWidgets()
  return widgets.render_response(response, sess.pos), err
end

return components
