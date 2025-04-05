---@mod lean.widgets Introduction

---@brief [[
--- Custom support for Lean (user) widgets.
---
--- We aren't a web browser (yet?) so we don't have generic support for widgets
--- which execute via Javascipt.
---
--- But this module "decompiles" specific widgets into TUI-accessible
--- components.
---@brief ]]

local dedent = require('std.text').dedent
local inductive = require 'std.inductive'

local InteractiveCode = require 'lean.widget.interactive_code'
local Element = require('lean.tui').Element
local update_goals_at = require('lean.goals').update_at
local log = require 'lean.log'

---@alias WidgetRenderer fun(ctx: RenderContext, props: any, hash: string): Element[]?

---A Lean user widget.
---@class Widget
---@field element WidgetRenderer
local Widget = {}
Widget.__index = Widget

---@class WidgetNewArgs
---@field element WidgetRenderer

---Create a new Widget.
---@param args WidgetNewArgs
---@return Widget
function Widget:new(args)
  local obj = { element = args.element }
  return setmetatable(obj, self)
end

---A null widget which indicates it is standing in for one not-yet-supported.
---@param id string the ID of the user widget we are not implementing
---@return Widget
function Widget.unsupported(id)
  return Widget:new {
    element = function()
      local title = vim.uri_encode(('Add support for `%s` widgets'):format(id))
      local msg = dedent [[
        %q is not a supported Lean widget type.
        If you think it could be, please file an issue at
        https://github.com/Julian/lean.nvim/issues/new/?title=%s
      ]]
      log:info { message = msg:format(id, title), id = id }
    end,
  }
end

---A registry of `Widget`s which we essentially reimplement in Lua rather than
---by executing their Javascript source modules.
local BYPASSED_WIDGETS = vim.defaulttable(Widget.unsupported)

---Implement the Lean user widget with the given ID (by
---bypassing its Javascript and calling the given function instead).
---@param id string
---@param element WidgetRenderer
---@return nil
local function implement(id, element)
  BYPASSED_WIDGETS[id] = Widget:new { element = element }
end

---Parse a supported user widget by bypassing it if it is supported.
---
---Unsupported widgets are ignored after logging a notice.
---@param user_widget UserWidget
---@return Widget
function Widget.from_user_widget(user_widget)
  return BYPASSED_WIDGETS[user_widget.id]
end

---Data and common helpers for an actively rendering widget.
---
---Passed to any function which implements a widget in order to interact with
---the rest of the environment.
---@class RenderContext
---@field private pos lsp.TextDocumentPositionParams the URI & position in the document whose widgets we are rendering
---@field private sess Subsession an RPC subsession for the current position
---@field private locations Locations selected locations in the goal state
local RenderContext = {}
RenderContext.__index = RenderContext

---@class RenderContextNewArgs
---@field pos lsp.TextDocumentPositionParams the URI & position in the document whose widgets we are rendering
---@field sess Subsession an RPC session for the current position
---@field locations Locations selected locations in the goal state

---Create a new render context.
---@param args RenderContextNewArgs
---@return RenderContext
function RenderContext:new(args)
  local obj = { pos = args.pos, sess = args.sess, locations = args.locations }
  return setmetatable(obj, self)
end

---Make a raw RPC call.
---@param method string
---@return any result
---@return LspError error
function RenderContext:rpc_call(method, params)
  return self.sess:call(method, params)
end

---The buffer we currently are rendering a widget to.
---@return number? bufnr
function RenderContext:bufnr()
  local bufnr = vim.uri_to_bufnr(self.pos.textDocument.uri)
  return vim.api.nvim_buf_is_loaded(bufnr) and bufnr or nil
end

---The last window before the user visited the infoview.
---
---Usually this is which Lean file they were editing.
---@return number? window
function RenderContext.get_last_window()
  local this_infoview = require('lean.infoview').get_current_infoview()
  local this_info = this_infoview and this_infoview.info
  return this_info and this_info.last_window
end

---The goals at the current infoview position.
---@return InteractiveGoal[]? goals
function RenderContext:get_goals()
  --FIXME: We re-request them here, rather than reusing what we got when
  --       building the infoview.
  return update_goals_at(self.pos, self.sess)
end

---Get the goal with the given MVar ID.
---@param mvar_id MVarId
---@return InteractiveGoal? goal
function RenderContext:goal_with_mvar_id(mvar_id)
  return vim.iter(self:get_goals()):find(function(goal)
    return goal.mvarId == mvar_id
  end)
end

---Retrieve the currently selected locations in the infoview.
---
---In VSCode this is "shift-click"-ing.
---@return GoalLocation[]
function RenderContext:selected_locations()
  return self.locations.selected
end

---Retrieve the Javascript source for the given widget.
---
---Usually this is useless as we aren't actually rendering Javascript, but it
---can be useful for implementing a widget to see what its source does.
---@param hash string the Javascript hash of the widget
---@return string source
function RenderContext:source_of(hash)
  local response = self.sess:getWidgetSource(self.pos.position, hash)
  return response and response.sourcetext
end

---Render a user widget instance into a TUI element.
---
---Unsupported widgets are ignored after logging a notice.
---@param instance UserWidgetInstance
---@param ctx RenderContext the surrounding context (data) for what we're rendering
---@return Element?
local function render(instance, ctx)
  local widget = Widget.from_user_widget(instance)
  return widget.element(ctx, instance.props, instance.javascriptHash)
end

-- -----------------
-- Lean core widgets
-- -----------------

---@alias SuggestionText string

---@class Suggestion
---@field suggestion SuggestionText Text to be used as a replacement via a code action.
---@field preInfo? string Optional info to be printed immediately before replacement text in a widget.
---@field postInfo? string Optional info to be printed immediately after replacement text in a widget.

---@class TryThisParams
---@field suggestions Suggestion[]
---@field range lsp.Range
---@field header string
---@field isInline boolean
---@field style any

---@param ctx RenderContext
---@param props TryThisParams
implement('Lean.Meta.Tactic.TryThis.tryThisWidget', function(ctx, props)
  local blocks = vim.iter(ipairs(props.suggestions)):map(function(i, each)
    local children = {
      i ~= 1 and Element:new { text = '\n' } or nil,
    }
    if each.preInfo then
      table.insert(children, Element:new { text = each.preInfo })
    end
    table.insert(
      children,
      Element:new {
        text = each.suggestion,
        highlightable = true,
        hlgroup = 'widgetLink',
        events = {
          click = function()
            local bufnr = ctx:bufnr()
            if not bufnr then
              return
            end

            ---@type lsp.TextEdit
            local edit = { range = props.range, newText = each.suggestion }
            vim.lsp.util.apply_text_edits({ edit }, bufnr, 'utf-16')

            local this_infoview = require('lean.infoview').get_current_infoview()
            local this_info = this_infoview and this_infoview.info
            local last_window = this_info and this_info.last_window
            if last_window and vim.api.nvim_win_get_buf(last_window) == bufnr then
              vim.api.nvim_set_current_win(last_window)
            end
          end,
        },
      }
    )
    if each.postInfo then
      table.insert(children, Element:new { text = each.postInfo })
    end
    return Element:new { children = children }
  end)
  return Element:titled {
    title = '▼ suggestion:',
    title_hlgroup = 'widgetSuggestion',
    margin = 1,
    body = blocks:totable(),
  }
end)

-- --------------------
-- ProofWidgets widgets
-- --------------------

---@class HtmlElement
---@field element { [1]: string, [2]: [string, any][], [3]: Html[] }

---@class HtmlText
---@field text string

---@class HtmlComponent
---@field component { [1]: string, [2]: string, [3]:  any, [4]: Html[] }

---@alias Html HtmlElement | HtmlText | HtmlComponent
local Html = inductive('Html', {
  ---@param text string
  ---@return Element
  text = function(_, text)
    return Element:new { text = text }
  end,

  ---@param value { [1]: string, [2]: string, [3]:  any, [4]: Html[] }
  ---@param ctx RenderContext
  ---@return Element
  component = function(self, value, sess)
    local hash, _, props, children = unpack(value)
    -- TODO: This should render export through our own bypassing logic,
    --       but we only have a hash here, not the ID...
    local elements = vim
      .iter(children)
      :map(function(child)
        return self(child, sess)
      end)
      :totable()
    return Element:new {
      children = {
        InteractiveCode(props.fmt, sess),
        Element:new { children = children },
      },
    }
  end,

  ---@param value { [1]: string, [2]: [string, any][], [3]: Html[] }
  ---@param ctx RenderContext
  ---@return Element
  element = function(self, value, ctx)
    local tag, _, children = unpack(value)
    local elements = vim
      .iter(children)
      :map(function(child)
        return self(child, ctx)
      end)
      :totable()
    if tag == 'span' then
      return Element:new { children = elements }
    end
    return Element:new { text = ('<%s>'):format(tag), children = elements }
  end,
})

---@class ExprPresentationData
---@field name string
---@field userName string
---@field html Html

---@param ctx RenderContext
---@return Element?
implement('ProofWidgets.GoalTypePanel', function(ctx, _)
  local goals = ctx:get_goals()
  if not goals or #goals == 0 then
    return
  end

  -- https://github.com/leanprover-community/ProofWidgets4/blob/a602d13aca2913724c7d47b2d7df0353620c4ee8/widget/src/presentSelection.tsx
  local goal = goals[1]
  local location = { mvarId = goal.mvarId, loc = { target = '/' } } ---@type GoalsLocation
  local params = { locations = { { goal.ctx, location } } }
  local expr = ctx:rpc_call('ProofWidgets.goalsLocationsToExprs', params).exprs[1]

  local response = ctx:rpc_call('ProofWidgets.getExprPresentations', { expr = expr })
  local presentations = response.presentations ---@type ExprPresentationData[]
  ---@type ExprPresentationData each
  local children = vim
    .iter(presentations)
    :map(function(each)
      -- XXX: Implement the rest of rendering a presentation which looks like it
      --      involves some <select> element implementation
      return Html(each.html, ctx.sess)
    end)
    :totable()
  return Element:new { children = children }
end)

local NO_SELECTION_HELP = Element:new {
  text = 'Nothing selected. You can use `gK` in the infoview to select expressions in the goal.',
}

---@param ctx RenderContext
implement('ProofWidgets.SelectionPanel', function(ctx, _)
  local selected = ctx:selected_locations()
  if #selected == 0 then
    return NO_SELECTION_HELP
  end
  local elements = vim.iter(selected):map(function(loc) ---@param loc GoalsLocation
    local goal = ctx:goal_with_mvar_id(loc.mvarId)
    if not goal then
      return -- FIXME
    end
    local expr = ctx:rpc_call('ProofWidgets.goalsLocationsToExprs', {
      locations = { { goal.ctx, loc } },
    }).exprs[1]

    -- TODO: Combine with GTP above (extract to helper)
    local response = ctx:rpc_call('ProofWidgets.getExprPresentations', { expr = expr })
    local presentations = response.presentations ---@type ExprPresentationData[]
    ---@type ExprPresentationData each
    local children = vim
      .iter(presentations)
      :map(function(each)
        -- XXX: Implement the rest of rendering a presentation which looks like it
        --      involves some <select> element implementation
        return Html(each.html, ctx.sess)
      end)
      :totable()
    return Element:new { children = children }
  end)
  if not elements:peek() then
    return
  end
  return Element:titled {
    title = '▼ Selected expressions:',
    title_hlgroup = 'Title',
    body = { Element:concat(elements:totable(), '\n') },
  }
end)

-- -------------------
-- ImportGraph widgets
-- -------------------

---@class GoToModuleLinkParams
---@field modName string the module to jump to

---A "jump to a module".
---@param ctx RenderContext
---@param props GoToModuleLinkParams
implement('GoToModuleLink', function(ctx, props)
  return Element:new {
    text = props.modName,
    highlightable = true,
    hlgroup = 'widgetLink',
    events = {
      go_to_def = function(_)
        local last_window = ctx.get_last_window()
        if not last_window then
          return
        end
        vim.api.nvim_set_current_win(last_window)
        local uri, err = ctx:rpc_call('getModuleUri', props.modName)
        if err then
          return -- FIXME: Yeah, this should go somewhere clearly.
        end
        ---@type lsp.Position
        local start = { line = 0, character = 0 }
        vim.lsp.util.show_document(
          { uri = uri, range = { start = start, ['end'] = start } },
          'utf-16',
          { focus = true }
        )
      end,
    },
  }
end)

return {
  Widget = Widget,
  implement = implement,

  ---A version of widget rendering that constructs a one-time render context.
  ---@param widget UserWidgetInstance
  ---@param sess Subsession
  ---@return Element?
  render = function(widget, sess)
    -- This is used in one place at the minute (in the infoview) and it's not
    -- clear whether it should be done in a different way yet.

    -- TODO: Is sess.pos the right position??
    --       I still don't really understand why we have positions on sessions,
    --       as we essentially never use this attribute (other than now here).
    local ctx = RenderContext:new { pos = sess.pos, sess = sess }
    return render(widget, ctx)
  end,

  ---Render the given response to one or more TUI elements.
  ---@param response? UserWidgets
  ---@param pos lsp.TextDocumentPositionParams the URI and position whose widgets we are receiving
  ---@param sess Subsession an RPC subsession for the current position
  ---@param locations Locations selected locations in the goal state
  ---@return Element[]? elements
  render_response = function(response, pos, sess, locations)
    if response then
      local ctx = RenderContext:new {
        pos = pos,
        sess = sess,
        locations = locations,
      }
      return vim
        .iter(response.widgets)
        ---@param widget UserWidgetInstance
        :map(function(widget)
          return render(widget, ctx)
        end)
        :totable()
    end
  end,
}
