---@mod lean.widgets Introduction

---@brief [[
--- Custom support for Lean (user) widgets.
---
--- We aren't a web browser (yet?) so we don't have generic support for widgets
--- which execute via Javascipt.
---
--- But this module "decompiles" specific widgets into TUI-accessible
--- components.
---
--- For widgets created via `mk_rpc_widget%` in ProofWidgets, we can
--- generically extract the RPC method name from their JavaScript source
--- and call it directly, without needing per-widget Lua implementations.
---@brief ]]

local dedent = require('std.text').dedent

local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'
local Locations = require 'lean.infoview.locations'
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
---@return ReconnectingSubsession
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
        title = Element.title('RPC Error: ' .. kind, 'ErrorMsg'),
        gap = 1,
        body = { Element:new { text = err.message } },
      }
  end
  return response
end

---Create a link that applies a text edit to the Lean source buffer.
---
---Applies the edit and jumps to the Lean window afterwards.
---@param text string the display text for the link
---@param range lsp.Range the range to replace
---@param new_text string the replacement text
---@return Element
function RenderContext:edit_link(text, range, new_text)
  return Element.link {
    text = text,
    name = 'suggestion',
    action = function()
      local bufnr = vim.uri_to_bufnr(self.params.textDocument.uri)
      if not vim.api.nvim_buf_is_loaded(bufnr) then
        log:warning {
          message = 'Cannot apply edits to unloaded buffer',
          bufnr = bufnr,
        }
        return
      end

      vim.lsp.util.apply_text_edits({ { range = range, newText = new_text } }, bufnr, 'utf-16')

      local last_window = self.get_last_window()
      if last_window and last_window:bufnr() == bufnr then
        last_window:make_current()
      end
    end,
  }
end

---The last window before the user visited the infoview.
---
---Usually this is which Lean file they were editing.
---@return Window? window
function RenderContext.get_last_window()
  local this_infoview = require('lean.infoview').get_current_infoview()
  return this_infoview and this_infoview.last_window
end

---The goals at the current infoview position.
---@return InteractiveGoal[]? goals
function RenderContext:get_goals()
  return goals.at(self:subsession())
end

---Get the goal with the given MVar ID.
---@param mvar_id MVarId
---@return InteractiveGoal? goal
function RenderContext:goal_with_mvar_id(mvar_id)
  return vim.iter(self:get_goals()):find(function(goal)
    return goal.mvarId == mvar_id
  end)
end

---Retrieve the Javascript source for the given widget.
---
---Usually this is useless as we aren't actually rendering Javascript, but it
---can be useful for implementing a widget to see what its source does.
---@param hash string the Javascript hash of the widget
---@return string source
function RenderContext:source_of(hash)
  local response = self:subsession():getWidgetSource(hash)
  return response and response.sourcetext
end

---See ProofWidgets.Component.Panel.Basic.
---@class PanelWidgetProps
---@field pos lsp.Position Cursor position in the file at which the widget is being displayed.
---@field goals InteractiveGoal[] The current tactic-mode goals.
---@field termGoal? InteractiveTermGoal The current term-mode goal, if any.
---@field selectedLocations GoalsLocation[] Locations currently selected in the goal state.

---The key bound to the given `<Plug>` mapping, or `nil` if none is found.
---
---Checks the current InfoView buffer's local mappings first, then global
---mappings.
---@param plug string the `<Plug>` name to look up
---@return string?
local function key_for_plug(plug)
  local iv = require('lean.infoview').get_current_infoview()
  local bufnr = iv and iv.pin and iv.pin.buffer and iv.pin.buffer.bufnr
  if bufnr then
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(bufnr, 'n')) do
      if m.rhs == plug then
        return m.lhs
      end
    end
  end
  for _, m in ipairs(vim.api.nvim_get_keymap 'n') do
    if m.rhs == plug then
      return m.lhs
    end
  end
end

---Help shown when the user hasn't selected any subexpressions yet.
---@return Element
local function no_selection_help()
  local parts = {
    Element.text 'Nothing selected. You can use',
    Element.kbd(key_for_plug '<Plug>(LeanInfoviewSelect)' or 'gK'),
  }
  if vim.o.mouse:find '[na]' then
    table.insert(parts, Element.text 'or')
    table.insert(
      parts,
      Element.kbd(key_for_plug '<Plug>(LeanInfoviewMouseSelect)' or '<C-LeftMouse>')
    )
  end
  table.insert(parts, Element.text 'in the infoview to select expressions in the goal.')
  return Element:concat(parts, ' ')
end

---A wrapper for widgets which interact with selected locations.
---
---Shows a hint for how to select locations if none are selected.
---
---Once some locations are selected, delegates to the wrapped widget function.
---@param widget_fn fun(ctx:RenderContext, props?:PanelWidgetProps):Element?
local function panel(widget_fn)
  ---@param ctx RenderContext
  ---@param props? PanelWidgetProps
  return function(ctx, props)
    local selected = Locations.selected_at(ctx.params)
    if #selected == 0 then
      return no_selection_help()
    end

    ---@type PanelWidgetProps
    local params = {
      pos = ctx.params.position,
      goals = ctx:get_goals(),
      selectedLocations = selected,
    }
    if type(props) == 'table' then
      params = vim.tbl_extend('error', params, props)
    end

    return widget_fn(ctx, params)
  end
end

---Cache of JS hash → extracted RPC method name (or false if not ofRpcMethod).
---@type table<string, string|false>
local rpc_method_cache = {}

---Extract the RPC method name from an ofRpcMethod JavaScript source.
---@param source string
---@return string? method the Lean-qualified RPC method name
local function rpc_method_from_source(source)
  -- The ofRpcMethod JS template assigns the RPC method to a minified
  -- variable.  We look for a Lean fully-qualified name (at least two
  -- dot-separated segments) that isn't one of the known constants
  -- baked into the template itself.
  for candidate in source:gmatch '"([%w_]+%.[%w_%.]+)"' do
    if
      candidate ~= 'react.jsx'
      and not candidate:find '^react/'
      and not candidate:find '^@'
      and candidate ~= 'ProofWidgets.checkRequest'
      and candidate ~= 'ProofWidgets.cancelRequest'
    then
      -- Strip the cancellable suffix — we call the base method directly.
      return (candidate:gsub('%._cancellable$', ''))
    end
  end
end

---Try to handle a widget via the `mk_rpc_widget%` / ofRpcMethod pattern.
---
---These widgets embed an RPC method name in their JavaScript source.
---We extract it and call the method directly.
---
---Since `getWidgets` only returns `PanelWidgetInstance`s, every widget
---reaching this path is a panel widget, so we wrap in `panel` for the
---terminal-appropriate "nothing selected" help text.
---@param ctx RenderContext
---@param props any
---@param hash string
---@return Element?
local function of_rpc_method(ctx, props, hash)
  local method = rpc_method_cache[hash]
  if method == nil then
    local source = ctx:source_of(hash)
    if source then
      method = rpc_method_from_source(source)
    end
    rpc_method_cache[hash] = method or false
  end
  if not method then
    return
  end

  return panel(function(inner_ctx, params)
    local response, err = inner_ctx:rpc_call(method, params)
    if err then
      return err
    end
    return Html(response, inner_ctx)
  end)(ctx, props)
end

---Parse a supported user widget by bypassing it if it is supported.
---
---Falls back to generic ofRpcMethod handling for `mk_rpc_widget%` widgets,
---and logs a notice for genuinely unsupported widgets.
---@param user_widget UserWidget
---@return Widget
function Widget.from_user_widget(user_widget)
  local lua_module = 'lean.widgets.' .. user_widget.id
  local ok, widget = pcall(require, lua_module)
  if ok then
    return Widget:new { element = widget }
  end

  local id = user_widget.id
  return Widget:new {
    element = function(ctx, props, hash)
      local element = of_rpc_method(ctx, props, hash)
      if element then
        return element
      end
      Widget.unsupported(id).element()
    end,
  }
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

  panel = panel,

  ---A version of widget rendering that constructs a one-time render context.
  ---@param widget UserWidgetInstance
  ---@param sess ReconnectingSubsession
  ---@return Element?
  render = function(widget, sess)
    -- This is used in one place at the minute (in the infoview) and it's not
    -- clear whether it should be done in a different way yet.

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
