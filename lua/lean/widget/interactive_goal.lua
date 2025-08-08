local InteractiveCode = require 'lean.widget.interactive_code'
local Element = require('lean.tui').Element
local config = require 'lean.config'
local range_to_string = require('std.lsp').range_to_string
local util = require 'lean._util'

local interactive_goal = {}

---A hypothesis name which is accessible according to Lean's naming conventions.
---@param name string
local function is_accessible(name)
  return name:sub(-#'✝') ~= '✝'
end

---Render a hypothesis name.
---@param name string
---@param mvar_id MVarId
---@param fvar_id FVarId
---@param locations? Locations
local function to_hypothesis_name(name, mvar_id, fvar_id, locations)
  local highlightable, select, hlgroup
  if locations and mvar_id and fvar_id then
    highlightable = true

    ---@type GoalsLocation
    local location = { mvarId = mvar_id, loc = { hyp = fvar_id } }

    function hlgroup()
      return locations:is_selected(location) and 'leanInfoSelected'
        or (is_accessible(name) and 'leanInfoHypName' or 'leanInfoInaccessibleHypName')
    end

    select = function()
      locations:toggle_selection(location)
    end
  end

  return Element:new {
    text = name,
    highlightable = highlightable,
    hlgroup = hlgroup,
    events = { select = select },
  }
end

---Render the hypothesis according to view options.
---@param hyp InteractiveHypothesisBundle
---@param mvar_id MVarId
---@param opts InfoviewViewOptions
---@param sess Subsession
---@param locations? Locations
local function to_hypothesis_element(hyp, mvar_id, opts, sess, locations)
  if (not opts.show_instances and hyp.isInstance) or (not opts.show_types and hyp.isType) then
    return
  end

  local names = vim
    .iter(ipairs(hyp.names))
    :map(function(i, name)
      if opts.show_hidden_assumptions or is_accessible(name) then
        return to_hypothesis_name(name, mvar_id, hyp.fvarIds[i], locations)
      end
    end)
    :totable()
  if #names == 0 then
    return
  end

  local type_locations = locations
    and mvar_id
    and hyp.fvarIds
    and hyp.fvarIds[1]
    and locations:in_template {
      mvarId = mvar_id,
      loc = { hypType = { hyp.fvarIds[1], '' } },
    }
  local element = Element:new {
    name = 'hyp',
    children = {
      Element:concat(names, ' ', {
        hlgroup = hyp.isInserted and 'leanInfoHypNameInserted'
          or hyp.isRemoved and 'leanInfoHypNameRemoved'
          or nil,
      }),
      Element:new { text = ' : ' },
      InteractiveCode(hyp.type, sess, type_locations),
    },
  }

  if opts.show_let_values and hyp.val then
    local val_locations = locations
      and mvar_id
      and hyp.fvarIds
      and hyp.fvarIds[1]
      and locations:in_template {
        mvarId = mvar_id,
        loc = { hypValue = { hyp.fvarIds[1], '' } },
      }
    element:add_child(Element:new {
      text = ' := ',
      name = 'hyp_val',
      children = { InteractiveCode(hyp.val, sess, val_locations) },
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
    return Element:titled {
      title = ('▼ %s: %s'):format(range_to_string(range), markers[diagnostic.severity]),
      body = {
        Element:new {
          -- So. #check foo gives back a diagnostic with *no* trailing newline
          -- but #eval foo gives back one *with* a trailing newline.
          -- VSCode displays both of them the same, so let's do that as well by
          -- essentially stripping off one trailing newline if present in a
          -- diagnostic message.
          text = diagnostic.message:gsub('\n$', ''),
        },
      },
      margin = 0,
    }
  end, util.lean_lsp_diagnostics({ lnum = params.position.line }, bufnr))
end

---@param goal InteractiveGoal | InteractiveTermGoal
---@param sess Subsession
---@param locations Locations? nil if we're rendering a term goal
function interactive_goal.Goal(goal, sess, locations)
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

  local goal_locations = locations
    and goal.mvarId
    and locations:in_template {
      mvarId = goal.mvarId,
      loc = { target = '' },
    }
  local goal_element = Element:new {
    name = 'goal',
    children = {
      Element:new { text = goal.goalPrefix or '⊢ ', hlgroup = 'leanInfoGoalPrefix' },
      InteractiveCode(goal.type, sess, goal_locations),
    },
  }
  local hyps = vim.iter(goal.hyps):map(function(hyp)
    return to_hypothesis_element(hyp, goal.mvarId, view_options, sess, locations)
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
---@param locations Locations
---@return Element[]
function interactive_goal.Goals(goals, sess, locations)
  ---@param goal InteractiveGoal
  local children = vim.iter(goals):map(function(goal)
    return interactive_goal.Goal(goal, sess, locations)
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

  return {
    Element:titled {
      title = ('▼ expected type (%s)'):format(range_to_string(goal.range)),
      body = { interactive_goal.Goal(goal, sess) },
      margin = 1,
    },
  }
end

return interactive_goal
