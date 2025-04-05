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
local RenderContext = {}
RenderContext.__index = RenderContext

---@class RenderContextNewArgs
---@field pos lsp.TextDocumentPositionParams the URI & position in the document whose widgets we are rendering
---@field sess Subsession an RPC session for the current position

---Create a new render context.
---@param args RenderContextNewArgs
---@return RenderContext
function RenderContext:new(args)
  local obj = { pos = args.pos, sess = args.sess }
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
  ---@return Element[]? elements
  render_response = function(response, pos, sess)
    if response then
      local ctx = RenderContext:new { pos = pos, sess = sess }
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
