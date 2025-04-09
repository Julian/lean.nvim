local InteractiveCode = require 'lean.widget.interactive_code'
local Element = require('lean.tui').Element
local config = require 'lean.config'
local range_to_string = require('std.lsp').range_to_string
local util = require 'lean._util'

local interactive_goal = {}

---Format a heading.
local function H(contents)
  return ('▼ %s'):format(contents)
end

---A hypothesis name which is accessible according to Lean's naming conventions.
---@param name string
local function is_accessible(name)
  return name:sub(-#'✝') ~= '✝'
end

local function to_hypothesis_element(hyp, opts, sess)
  if (not opts.show_instances and hyp.isInstance) or (not opts.show_types and hyp.isType) then
    return
  end

  local names = vim.iter(hyp.names)
  if not opts.show_hidden_assumptions then
    names = names:filter(is_accessible)
  end
  if not names:peek() then
    return
  end

  local element = Element:new {
    name = 'hyp',
    children = {
      Element:new {
        text = names:join ' ',
        hlgroup = hyp.isInserted and 'leanInfoHypNameInserted'
          or hyp.isRemoved and 'leanInfoHypNameRemoved'
          or nil,
      },
      Element:new { text = ' : ' },
      InteractiveCode(hyp.type, sess),
    },
  }

  if opts.show_let_values and hyp.val then
    element:add_child(Element:new {
      text = ' := ',
      name = 'hyp_val',
      children = { InteractiveCode(hyp.val, sess) },
    })
  end

  return element
end

---Diagnostic information for the current line from the Lean server.
---@param params lsp.TextDocumentPositionParams
---@return Element[]
function interactive_goal.diagnostics(params)
  local markers = config().infoview.severity_markers

  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return {}
  end

  ---@param diagnostic vim.Diagnostic
  return vim.tbl_map(function(diagnostic)
    local range = diagnostic.user_data
        and diagnostic.user_data.lsp
        and diagnostic.user_data.lsp.fullRange
      ---@type lsp.Range
      or {
        start = {
          line = diagnostic.lnum,
          character = diagnostic.col,
        },
        ['end'] = {
          line = diagnostic.end_lnum,
          character = diagnostic.end_col,
        },
      }
    return Element:new {
      name = 'diagnostic',
      text = H(string.format(
        '%s: %s%s',
        range_to_string(range),
        markers[diagnostic.severity],
        -- So. #check foo gives back a diagnostic with *no* trailing newline
        -- but #eval foo gives back one *with* a trailing newline.
        -- VSCode displays both of them the same, so let's do that as well by
        -- essentially stripping off one trailing newline if present in a
        -- diagnostic message.
        diagnostic.message:gsub('\n$', '')
      )),
    }
  end, util.lean_lsp_diagnostics({ lnum = params.position.line }, bufnr))
end

---@param goal InteractiveGoal | InteractiveTermGoal
---@param sess Subsession
function interactive_goal.interactive_goal(goal, sess)
  local view_options = config().infoview.view_options or {}

  local case
  if goal.userName then
    case = Element:new {
      children = {
        Element:new { text = 'case ', hlgroup = 'leanInfoGoalCase' },
        Element:new { text = goal.userName .. '\n' },
      },
    }
  end
  local children = { case }

  local goal_element = Element:new {
    text = goal.goalPrefix or '⊢ ',
    name = 'goal',
    children = { InteractiveCode(goal.type, sess) },
  }
  local hyps = vim.iter(goal.hyps):map(function(hyp)
    return to_hypothesis_element(hyp, view_options, sess)
  end)

  local separator = Element:new { text = '\n' }
  if view_options.reverse then
    table.insert(children, goal_element)
    if hyps:peek() then
      table.insert(children, separator)
      table.insert(children, Element:concat(hyps:rev():totable(), '\n'))
    end
  else
    if hyps:peek() then
      table.insert(children, Element:concat(hyps:totable(), '\n'))
      table.insert(children, separator)
    end
    table.insert(children, goal_element)
  end

  return Element:new { name = 'interactive-goal', children = children }
end

---@param goals InteractiveGoal[]
---@param sess Subsession
---@return Element[]
function interactive_goal.interactive_goals(goals, sess)
  local children = vim.iter(goals):map(function(goal)
    return interactive_goal.interactive_goal(goal, sess)
  end)
  return { Element:concat(children:totable(), '\n\n') }
end

---The current (term) goal state.
---@param goal InteractiveTermGoal
---@param sess Subsession
---@return Element[]
function interactive_goal.interactive_term_goal(goal, sess)
  if not goal then
    return {}
  end

  local term_state_element = Element:new {
    text = H(string.format('expected type (%s)\n', range_to_string(goal.range))),
    name = 'term-state',
    children = { interactive_goal.interactive_goal(goal, sess) },
  }
  return {
    Element:new {
      name = 'interactive-term-goal',
      children = { term_state_element },
    },
  }
end

return interactive_goal
