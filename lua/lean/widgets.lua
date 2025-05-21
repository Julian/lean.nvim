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
local goals = require 'lean.goals'
local log = require 'lean.log'
local rpc = require 'lean.rpc'

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
        %q is not a supported Lean widget.
        If you think it could be, please file an issue at
        https://github.com/Julian/lean.nvim/issues/new/?title=%s
      ]]
      log:info { message = msg:format(id, title), id = id }
    end,
  }
end

---Parse a supported user widget by bypassing it if it is supported.
---
---Unsupported widgets are ignored after logging a notice.
---@param user_widget UserWidget
---@return Widget
function Widget.from_user_widget(user_widget)
  local lua_module = 'lean.widgets.' .. user_widget.id
  local ok, widget = pcall(require, lua_module)
  if not ok then
    return Widget.unsupported(user_widget.id)
  end
  return Widget:new { element = widget }
end

---Data and common helpers for an actively rendering widget.
---
---Passed to any function which implements a widget in order to interact with
---the rest of the environment.
---@class RenderContext
---@field private params lsp.TextDocumentPositionParams the document and position whose widgets we are rendering
local RenderContext = {}
RenderContext.__index = RenderContext

---Create a new render context.
---
---@param params lsp.TextDocumentPositionParams the document and position whose widgets we are rendering
---@return RenderContext
function RenderContext:new(params)
  return setmetatable({ params = params }, self)
end

---Open an RPC session for the current position.
---
---Prefer using a higher level API (or adding one) over calling this!
---@return Subsession
function RenderContext:subsession()
  return rpc.open(self.params)
end

---Make a raw RPC call.
---
---Prefer using an even higher level API (or adding one) over calling this!
---@param method string
---@return any result
---@return Element? error if an error occurs, an element which will render it
function RenderContext:rpc_call(method, params)
  local response, err = self:subsession():call(method, params)
  if err then
    local kind = vim.lsp.protocol.ErrorCodes[err.code] or tostring(err.code)
    return nil,
      Element:titled {
        title = 'RPC Error: ' .. kind,
        title_hlgroup = 'ErrorMsg',
        margin = 1,
        body = { Element:new { text = err.message } },
      }
  end
  return response
end

---Apply text edits to the Lean source buffer whose widgets we are rendering.
---
---Jumps to the Lean window afterwards if it was the last window.
---@param edits lsp.TextEdit[]
function RenderContext:apply_edits(edits)
  local bufnr = vim.uri_to_bufnr(self.params.textDocument.uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    log:warning {
      message = 'Cannot apply edits to unloaded buffer',
      bufnr = bufnr,
      edits = edits,
    }
    return
  end

  vim.lsp.util.apply_text_edits(edits, bufnr, 'utf-16')

  local last_window = self.get_last_window()
  if last_window and last_window:bufnr() == bufnr then
    last_window:make_current()
  end
end

---The last window before the user visited the infoview.
---
---Usually this is which Lean file they were editing.
---@return Window? window
function RenderContext.get_last_window()
  local this_infoview = require('lean.infoview').get_current_infoview()
  local this_info = this_infoview and this_infoview.info
  return this_info and this_info.last_window
end

---The goals at the current infoview position.
---@return InteractiveGoal[]? goals
function RenderContext:get_goals()
  return goals.at(self.params, self:subsession())
end

---Retrieve the Javascript source for the given widget.
---
---Usually this is useless as we aren't actually rendering Javascript, but it
---can be useful for implementing a widget to see what its source does.
---@param hash string the Javascript hash of the widget
---@return string source
function RenderContext:source_of(hash)
  local response = self:subsession():getWidgetSource(self.params.position, hash)
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

return {
  Widget = Widget,

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
    local ctx = RenderContext:new(sess.pos)
    return render(widget, ctx)
  end,

  ---Render the given response to one or more TUI elements.
  ---@param response? UserWidgets
  ---@param params lsp.TextDocumentPositionParams the URI and position whose widgets we are receiving
  ---@return Element[]? elements
  render_response = function(response, params)
    if response then
      local ctx = RenderContext:new(params)
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
