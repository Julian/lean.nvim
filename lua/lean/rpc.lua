---@mod lean.rpc RPC

---@brief [[
--- Low-level RPC with the Lean server.
---
--- See Lean/Server/FileWorker/WidgetRequests.lean for the Lean side of many of
--- the below data structures.
---@brief ]]

local a = require 'plenary.async'
local control = require 'plenary.async.control'
local lsp = require 'lean.lsp'
local util = require 'lean._util'

local uv = vim.uv or vim.loop

local rpc = {}

---@class RpcRef

---@class Session
---@field client vim.lsp.Client
---@field uri string
---@field connected? boolean
---@field session_id? string
---@field connect_err? string
---@field on_connected Condvar
---@field keepalive_timer? uv_timer_t
---@field to_release RpcRef[]
---@field release_timer? table
local Session = {}
Session.__index = Session

---@param client vim.lsp.Client
---@param bufnr number
---@param uri string
---@return Session
function Session:new(client, bufnr, uri)
  self = setmetatable({
    client = client,
    uri = uri,
    session_id = nil,
    connected = nil,
    connect_err = nil,
    on_connected = control.Condvar.new(),
    to_release = {},
    release_timer = nil,
  }, self)
  self.keepalive_timer = uv.new_timer()
  self.keepalive_timer:start(
    20000, -- Lean.Server.FileWorker.Utils defines this to be 30000(ms)
    20000, -- so we use a value to stay under that.
    vim.schedule_wrap(function()
      if not self:is_closed() and self.session_id ~= nil then
        self.client.notify('$/lean/rpc/keepAlive', {
          uri = self.uri,
          sessionId = self.session_id,
        })
      end
    end)
  )
  -- Terminate RPC session when document is closed.
  vim.api.nvim_buf_attach(bufnr, false, {
    on_reload = function()
      self:close_without_releasing()
    end,
    on_detach = function()
      self:close_without_releasing()
    end,
  })
  return self
end

function Session:is_closed()
  if self.client and self.client.is_stopped() then
    self:close_without_releasing()
  end
  return self.client == nil
end

function Session:close_without_releasing()
  if self.keepalive_timer then
    self.keepalive_timer:close()
    self.keepalive_timer = nil
  end
  self.client = nil
end

function Session:close()
  self:release_now {}
  self:close_without_releasing()
end

---@param refs RpcRef[]
function Session:release_now(refs)
  vim.list_extend(self.to_release, refs)
  if #self.to_release == 0 or self:is_closed() then
    return
  end
  ---@diagnostic disable-next-line: undefined-field
  self.client.notify('$/lean/rpc/release', {
    uri = self.uri,
    sessionId = self.session_id,
    refs = self.to_release,
  })
  self.to_release = {}
end

---@param refs RpcRef[]
function Session:release_deferred(refs)
  vim.list_extend(self.to_release, refs)
  if self.release_timer == nil then
    self.release_timer = vim.defer_fn(function()
      self.release_timer = nil
      self:release_now {}
    end, 100)
  end
end

---@param pos lsp.TextDocumentPositionParams
---@param method string
---@return any result
---@return LspError error
function Session:call(pos, method, params)
  while not self.connected do
    ---@diagnostic disable-next-line: undefined-field
    self.on_connected:wait()
  end
  if self.connect_err ~= nil then
    return nil, self.connect_err
  end
  if self:is_closed() then
    return nil, { code = -32900, message = 'LSP server disconnected' }
  end
  local err, result = util.client_a_request(
    self.client,
    '$/lean/rpc/call',
    vim.tbl_extend('error', pos, { sessionId = self.session_id, method = method, params = params })
  )
  if err ~= nil and err.code == -32900 then
    self:close_without_releasing()
  end
  local function register(obj)
    if type(obj) == 'table' then
      for k, v in pairs(obj) do
        if k == 'p' and type(v) ~= 'table' then
          -- Lua 5.1 workaround for unsupported __gc on tables
          -- luacheck: ignore
          local prox = newproxy(true)
          getmetatable(prox).__gc = function()
            self:release_deferred { { p = v } }
          end
          setmetatable(obj, { [prox] = true })
        else
          register(v)
        end
      end
    end
  end
  register(result)
  return result, err
end

--- Map from bufnr to Session object.
---@type table<number, Session>
local sessions = {}

---@param uri string
---@result string error
local function connect(uri)
  local bufnr = vim.uri_to_bufnr(uri)
  local client = lsp.client_for(bufnr)
  local sess = Session:new(client, bufnr, uri)
  sessions[uri] = sess
  if client == nil then
    sess.connected = true
    local err = 'Lean 4 LSP server not found'
    sess.connect_err = err
    return err
  end
  a.void(function()
    local err, result = util.client_a_request(client, '$/lean/rpc/connect', { uri = uri })
    sess.connected = true
    if err ~= nil then
      sess.connect_err = err
    else
      sess.session_id = result.sessionId
      sess.connect_err = nil
    end
    ---@diagnostic disable-next-line: undefined-field
    sess.on_connected:notify_all()
    return err
  end)()
end

---@class Subsession
---@field pos lsp.TextDocumentPositionParams
---@field sess Session
local Subsession = {}
Subsession.__index = Subsession

---@param sess Session
---@param pos lsp.TextDocumentPositionParams
function Subsession:new(sess, pos)
  return setmetatable({ sess = sess, pos = pos, refs = {} }, self)
end

---@param method string
---@return any result
---@return LspError error
function Subsession:call(method, params)
  return self.sess:call(self.pos, method, params)
end

--- Open an RPC session.
---@param params lsp.TextDocumentPositionParams
---@return Subsession
function rpc.open(params)
  local uri = params.textDocument.uri
  if sessions[uri] == nil or sessions[uri].connect_err or sessions[uri]:is_closed() then
    connect(uri)
  end
  return Subsession:new(sessions[uri], params)
end

---@class InfoWithCtx

---@alias DiffTag 'wasChanged' | 'willChange' | 'wasDeleted' | 'willDelete' | 'wasInserted' | 'willInsert'
---@alias SubexprPos string

---@class SubexprInfo
---@field info InfoWithCtx
---@field subexprPos? SubexprPos
---@field diffStatus? DiffTag

---@class CodeWithInfos
---@field text? string
---@field append? CodeWithInfos[]
---@field tag? {[1]: SubexprInfo, [2]: CodeWithInfos}

---@class InfoPopup
---@field type CodeWithInfos?
---@field exprExplicit CodeWithInfos?
---@field doc string?

---@alias FVarId string
---@alias MVarId string

---@class InteractiveHypothesisBundle
---@field names string[]
---@field fvarIds? FVarId[]
---@field type CodeWithInfos
---@field val? CodeWithInfos
---@field isInstance? boolean
---@field isType? boolean
---@field isInserted? boolean
---@field isRemoved? boolean

---@class ContextInfo
---@class TermInfo

---@class InteractiveGoalCore
---@field hyps InteractiveHypothesisBundle[]
---@field type CodeWithInfos
---@field ctx ContextInfo

---@class InteractiveGoal: InteractiveGoalCore
---@field userName? string
---@field goalPrefix? string
---@field mvarId MVarId
---@field isInserted? boolean
---@field isRemoved? boolean

---@class InteractiveTermGoal
---@field range? lsp.Range
---@field term TermInfo

---@class InteractiveGoals
---@field goals InteractiveGoal[]

---@param pos lsp.TextDocumentPositionParams
---@return InteractiveGoals goals
---@return LspError error
function Subsession:getInteractiveGoals(pos)
  return self:call('Lean.Widget.getInteractiveGoals', pos)
end

---@param pos lsp.TextDocumentPositionParams
---@return InteractiveTermGoal
---@return LspError error
function Subsession:getInteractiveTermGoal(pos)
  return self:call('Lean.Widget.getInteractiveTermGoal', pos)
end

---@class TaggedTextMsgEmbed
---@field text? string
---@field append? TaggedTextMsgEmbed[]
---@field tag? {[1]: MsgEmbed} -- the second field is always the empty string

---@class StrictTraceChildrenEmbed
---@field strict TaggedTextMsgEmbed[]

---@class LazyTraceChildren

---@class LazyTraceChildrenEmbed
---@field lazy LazyTraceChildren

---@class WidgetEmbed
---@field wi UserWidgetInstance A widget instance.
---@field alt TaggedTextMsgEmbed a fallback rendering of the widget

---@class TraceEmbed
---@field indent integer
---@field cls string
---@field msg TaggedTextMsgEmbed
---@field collapsed boolean
---@field children StrictTraceChildrenEmbed | LazyTraceChildrenEmbed

---@class MessageData

---@class MsgEmbedExpr
---@field expr CodeWithInfos A piece of Lean code with elaboration/typing data.

---@class MsgEmbedGoal
---@field goal InteractiveGoal An interactive goal display.

---@class MsgEmbedWidget
---@field widget WidgetEmbed A widget instance.

---@class MsgEmbedTrace
---@field trace TraceEmbed Traces are too costly to print eagerly.

---@alias MsgEmbed MsgEmbedExpr | MsgEmbedGoal | MsgEmbedWidget | MsgEmbedTrace

---@class InteractiveDiagnostic
---@field range lsp.Range
---@field fullRange? lsp.Range
---@field severity? lsp.DiagnosticSeverity
---@field message TaggedTextMsgEmbed

---@class LineRange
---@field start integer
---@field end integer

---@param lineRange? LineRange
---@return InteractiveDiagnostic[]
---@return LspError error
function Subsession:getInteractiveDiagnostics(lineRange)
  return self:call('Lean.Widget.getInteractiveDiagnostics', { lineRange = lineRange })
end

---@param msg MessageData
---@param indent number
---@return TaggedTextMsgEmbed
---@return LspError error
function Subsession:msgToInteractive(msg, indent)
  return self:call(
    'Lean.Widget.InteractiveDiagnostics.msgToInteractive',
    { msg = msg, indent = indent }
  )
end

---@param children LazyTraceChildren
---@return TaggedTextMsgEmbed[]
---@return LspError error
function Subsession:lazyTraceChildrenToInteractive(children)
  return self:call('Lean.Widget.lazyTraceChildrenToInteractive', children)
end

---@param info InfoWithCtx
---@return InfoPopup
---@return LspError error
function Subsession:infoToInteractive(info)
  return self:call('Lean.Widget.InteractiveDiagnostics.infoToInteractive', info)
end

---@alias GoToKind 'declaration' | 'definition' | 'type'

---@param kind GoToKind
---@param info InfoWithCtx
---@return lsp.LocationLink[]
---@return LspError error
function Subsession:getGoToLocation(kind, info)
  return self:call('Lean.Widget.getGoToLocation', { kind = kind, info = info })
end

---@class UserWidget
---@field id string Name of the `@[widget_module]`
---@field javascriptHash string Hash of the JS source of the widget module.

---@class UserWidgetInstance: UserWidget
---@field props any SON object to be passed as props to the component
---@field range lsp.Range

---@class UserWidgets
---@field widgets UserWidgetInstance[]

---@param pos lsp.Position
---@return UserWidgets
---@return LspError error
function Subsession:getWidgets(pos)
  return self:call('Lean.Widget.getWidgets', pos)
end

---@class WidgetSource
---@field sourcetext string JavaScript sourcecode.
---                         Should be a plain JavaScript ESModule whose default
---                         export is the component to render.

---@class GetWidgetSourceParams
---@field pos lsp.Position
---@field hash string

---@param pos GetWidgetSourceParams
---@return WidgetSource
---@return LspError error
function Subsession:getWidgetSource(pos)
  return self:call('Lean.Widget.getWidgetSource', pos)
end

---@class GoalLocationHyp
---@field hyp FVarId

---@class GoalLocationHypType
---@field hypType {[1]: FVarId, [2]: SubexprPos}

---@class GoalLocationHypValue
---@field hypValue {[1]: FVarId, [2]: SubexprPos}

---@class GoalLocationTarget
---@field target SubexprPos

---@alias GoalLocation GoalLocationHyp | GoalLocationHypType | GoalLocationHypValue |  GoalLocationTarget

---@class GoalsLocation
---@field mvarId MVarId
---@field loc GoalLocation

return rpc

---@class LspErrorCodeMessage
---@field code lsp.ErrorCodes
---@field message? string

---@alias LspError LspErrorCodeMessage|string
