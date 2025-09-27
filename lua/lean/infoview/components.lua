---@brief [[
--- Infoview components which can be assembled to show various information
--- about the current Lean module or state.
---@brief ]]

---@tag lean.infoview.components

local range_to_string = require('std.lsp').range_to_string

local Element = require('lean.tui').Element
local Locations = require 'lean.infoview.locations'
local TaggedTextMsgEmbed = require('lean.widget.interactive_diagnostic').TaggedTextMsgEmbed
local config = require 'lean.config'
local diagnostic = require 'lean.diagnostic'
local goals = require 'lean.goals'
local interactive_goal = require 'lean.widget.interactive_goal'
local lsp = require 'lean.lsp'
local plain = require 'lean.infoview.plain'
local rpc = require 'lean.rpc'
local widgets = require 'lean.widgets'

local components = {
  LSP_HAS_DIED = Element:new {
    text = '🪦 The Lean language server is dead.',
    hlgroup = 'DiagnosticError',
  },
  NO_INFO = Element:new { text = 'No info.', name = 'no-info' },
  PROCESSING = Element:new { text = 'Processing file...', name = 'processing' },
}

---Diagnostic information for the current line from the Lean server.
---@param line number
---@param diags InteractiveDiagnostic[]
---@param sess Subsession
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
      return Element:new {
        text = ('▼ %s: %s'):format(range_to_string(range), markers[each.severity]),
        name = 'diagnostic',
        children = { TaggedTextMsgEmbed(each.message, sess) },
      }
    end)
    :totable()
end

---@param params lsp.TextDocumentPositionParams
---@param sess Subsession
---@param use_widgets? boolean
---@return Element[]? goal
---@return LspError? error
function components.goal_at(params, sess, use_widgets)
  local children, goal, err
  if use_widgets == false then
    goal, children = plain.goal(params)
  else
    goal, err = goals.at(params, sess)
    if err then
      goal, err = goals.at(params, rpc.open(params))
      -- FIXME: This is again our need for general retrying and/or flakiness
      --        which happens if we make RPC calls too quickly in our tests.
      if err then
        return nil, err
      end
    end
    children = goal and interactive_goal.Goals(goal, sess, Locations.at(params))
  end

  if goal and #goal > 1 then
    children = {
      Element:titled {
        title = ('▼ %d goals'):format(#goal),
        body = children,
        margin = 1,
        title_hlgroup = 'leanInfoMultipleGoals',
      },
    }
  end

  local title
  if lsp.goals_accomplished_at(params) then
    title = 'Goals accomplished 🎉'
  elseif goal and #goal == 0 then -- between goals / Lean <4.19 with no markers
    title = vim.g.lean_no_goals_message or 'No goals.'
  else
    return children, err
  end

  local element = Element:titled {
    title = title,
    body = children,
    title_hlgroup = 'leanInfoGoals',
  }
  return { element }, err
end

---@param params lsp.TextDocumentPositionParams
---@param sess Subsession
---@param use_widgets? boolean
---@return Element[]?
---@return LspError?
function components.term_goal_at(params, sess, use_widgets)
  -- Term goals, even in VSCode, seem to not support selecting subexpression
  -- locations / "shift-click"ing, so there's no `locations` parameter here.
  if use_widgets == false then
    return plain.term_goal(params)
  end

  local term_goal, err = sess:getInteractiveTermGoal(params)
  term_goal = term_goal and interactive_goal.interactive_term_goal(term_goal, sess)
  return term_goal, err
end

---Retrieve the interactive diagnostics at the given line.
---
---Filters out silent diagnostics which we show elsewhere.
---@param sess Subsession
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

---@param params lsp.TextDocumentPositionParams
---@param sess? Subsession
---@param use_widgets? boolean
---@return Element[]?
---@return LspError?
function components.diagnostics_at(params, sess, use_widgets)
  if use_widgets == false then
    return interactive_goal.diagnostics(params)
  end

  if sess == nil then
    sess = rpc.open(params)
  end

  local line = params.position.line
  local diagnostics, err = interactive_diagnostics_for(sess, line)
  if err then
    -- GENERALIZEME: This is the same kind of code as below for widgets, where
    --               we seem to need some higher-level retry logic.
    --               The difference here clearly is that we want to at some
    --               point fallback to non-interactive diagnostics if we see
    --               repeated failure I think, though maybe that should happen
    --               at the caller.
    diagnostics, err = interactive_diagnostics_for(rpc.open(params), line)
    if err then
      return interactive_goal.diagnostics(params), err
    end
  end

  ---We filter goals accomplished diagnostics from showing in the infoview, as
  ---they'll be indicated at the top.
  ---@param each DiagnosticWith<TaggedText.MsgEmbed>
  local filtered = vim.iter(diagnostics):filter(function(each)
    return not diagnostic.is_goals_accomplished(each)
  end)
  return components.interactive_diagnostics(filtered, line, sess), err
end

---@param params lsp.TextDocumentPositionParams
---@param sess? Subsession
---@param use_widgets? boolean
---@return Element[]? widgets
---@return LspError? error
function components.user_widgets_at(params, sess, use_widgets)
  if not use_widgets then
    return {}
  elseif sess == nil then
    sess = rpc.open(params)
  end
  local response, err = sess:getWidgets(params.position)
  -- luacheck: max_comment_line_length 200
  -- GENERALIZEME: This retry logic helps us pass a test, but belongs higher up
  --               in a way which parallels this VSCode retrying logic:
  --               https://github.com/leanprover/vscode-lean4/blob/33e54067d5fefcdf7f28e4993324fd486a53421c/lean4-infoview/src/infoview/info.tsx#L465-L470
  --               and/or generically retries RPC calls
  if not response then
    sess = rpc.open(params)
    response, err = sess:getWidgets(params.position)
  end
  return widgets.render_response(response, params), err
end

return components
