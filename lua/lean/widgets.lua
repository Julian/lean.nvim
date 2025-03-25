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

local Element = require('lean.tui').Element
local dedent = require('lean._util').dedent
local log = require 'lean.log'

---@alias WidgetRenderer fun(self: Widget, props: any, pos: lsp.TextDocumentPositionParams): Element[]?

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

---Render a user widget instance into a TUI element.
---
---Unsupported widgets are ignored after logging a notice.
---@param instance UserWidgetInstance
---@param pos lsp.TextDocumentPositionParams the URI & position in the document whose widgets we are rendering
---@return Element?
local function render(instance, pos)
  return Widget.from_user_widget(instance):element(instance.props, pos)
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

---@param props TryThisParams
---@param pos lsp.TextDocumentPositionParams
implement('Lean.Meta.Tactic.TryThis.tryThisWidget', function(_, props, pos)
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
            local bufnr = vim.uri_to_bufnr(pos.textDocument.uri)
            if not vim.api.nvim_buf_is_loaded(bufnr) then
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
  return Element.box {
    title = 'suggestion',
    titlehl = 'widgetSuggestion',
    children = blocks:totable(),
  }
end)

-- -------------------
-- ImportGraph widgets
-- -------------------

---@class GoToModuleLinkParams
---@field modName string the module to jump to

---A "jump to a module".
---@param props GoToModuleLinkParams
implement('GoToModuleLink', function(_, props)
  return Element:new {
    text = props.modName,
    highlightable = true,
    hlgroup = 'widgetLink',
    events = {
      go_to_def = function(_)
        local this_infoview = require('lean.infoview').get_current_infoview()
        local this_info = this_infoview and this_infoview.info
        local last_window = this_info and this_info.last_window
        if not last_window then
          return
        end
        vim.api.nvim_set_current_win(last_window)

        -- FIXME: Clearly we need to be able to get a session without touching
        --        internals... Probably this should be a method on ctx.
        local params = this_info.pin.__position_params
        local sess = require('lean.rpc').open(params)
        local uri, err = sess:call('getModuleUri', props.modName)
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
  render = render,

  ---Render the given response to one or more TUI elements.
  ---@param response? UserWidgets
  ---@param pos lsp.TextDocumentPositionParams the URI and position whose widgets we are receiving
  ---@param _ fun(widget: UserWidgetInstance):string,LspError retrieve the JS source of a widget
  ---@return Element[]? elements
  render_response = function(response, pos, _)
    if response then
      return vim
        .iter(response.widgets)
        ---@param widget UserWidgetInstance
        :map(function(widget)
          return render(widget, pos)
        end)
        :totable()
    end
  end,
}
