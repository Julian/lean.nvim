---@brief [[
--- RPC with the Lean server.
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
---@field connected boolean
---@field session_id string?
---@field connect_err string?
---@field on_connected function
---@field keepalive_timer any
---@field to_release RpcRef[]
---@field release_timer any
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
    20000,
    20000,
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
  for _, ptr in ipairs(refs) do
    table.insert(self.to_release, ptr)
  end
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
  for _, ptr in ipairs(refs) do
    table.insert(self.to_release, ptr)
  end
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

---@param bufnr number
---@result string error
local function connect(bufnr)
  local client = lsp.client_for(bufnr)
  local uri = vim.uri_from_bufnr(bufnr)
  local sess = Session:new(client, bufnr, uri)
  sessions[bufnr] = sess
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

function rpc.open(bufnr, params)
  if sessions[bufnr] == nil or sessions[bufnr].connect_err or sessions[bufnr]:is_closed() then
    connect(bufnr)
  end
  return Subsession:new(sessions[bufnr], params)
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

---@class LazyTraceChildren

---@class StrictOrLazyTraceChildren
---@field strict? TaggedTextMsgEmbed[]
---@field lazy? LazyTraceChildren

---@class TraceEmbed
---@field indent integer
---@field cls string
---@field msg TaggedTextMsgEmbed
---@field collapsed boolean
---@field children StrictOrLazyTraceChildren

---@class MessageData

---@class MsgEmbed
---@field expr? CodeWithInfos
---@field goal? InteractiveGoal
---@field trace? TraceEmbed
---@field lazyTrace? {[1]: number, [2]: string, [3]: MessageData}

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

-- TODO: Figure out how to load these from vim.lsp._meta

---@alias lsp.Handler fun(err: lsp.ResponseError?, result: any, context: lsp.HandlerContext, config?: table): ...any

---@class lsp.HandlerContext
---@field method string
---@field client_id integer
---@field bufnr? integer
---@field params? any
---@field version? integer

---@class lsp.ResponseError
---@field code integer
---@field message string
---@field data string|number|boolean|table[]|table|nil

-- TODO: Figure out how to load these from vim.lsp.Client

---@class vim.lsp.Client
--- Sends a notification to an LSP server.
--- Returns: a boolean to indicate if the notification was successful. If
--- it is false, then it will always be false (the client has shutdown).
--- @field notify fun(method: string, params: table?): boolean
---
--- Sends a request to the server.
--- This is a thin wrapper around {client.rpc.request} with some additional
--- checking.
--- If {handler} is not specified,  If one is not found there, then an error
--- will occur. Returns: {status}, {[client_id]}. {status} is a boolean
--- indicating if the notification was successful. If it is `false`, then it
--- will always be `false` (the client has shutdown).
--- If {status} is `true`, the function returns {request_id} as the second
--- result. You can use this with `client.cancel_request(request_id)` to cancel
--- the request.
--- @field request fun(method: string, params: table?, handler: lsp.Handler?, bufnr: integer?): boolean, integer?
--- Checks whether a client is stopped.
--- Returns: true if the client is fully stopped.
--- @field is_stopped fun(): boolean

-- TODO: Figure out how to load these from vim.lsp._meta.protocol

---@alias uinteger integer
---@alias lsp.DocumentUri string

---A literal to identify a text document in the client.
---@class lsp.TextDocumentIdentifier
---
---The text document's uri.
---@field uri lsp.DocumentUri

---Predefined error codes.
---@alias lsp.ErrorCodes
---| -32700 # ParseError
---| -32600 # InvalidRequest
---| -32601 # MethodNotFound
---| -32602 # InvalidParams
---| -32603 # InternalError
---| -32002 # ServerNotInitialized
---| -32001 # UnknownErrorCode

---@alias lsp.LSPErrorCodes
---| -32803 # RequestFailed
---| -32802 # ServerCancelled
---| -32801 # ContentModified
---| -32800 # RequestCancelled

---@class lsp.Position
---
---Line position in a document (zero-based).
---
---If a line number is greater than the number of lines in a document,
---it defaults back to the number of lines in the document.
---If a line number is negative, it defaults to 0.
---@field line uinteger
---
---Character offset on a line in a document (zero-based).
---
---The meaning of this offset is determined by the negotiated
---`PositionEncodingKind`.
---
---If the character value is greater than the line length it defaults back to the
---line length.
---@field character uinteger

---A range in a text document expressed as (zero-based) start and end positions.
---
---If you want to specify a range that contains a line including the line ending
---character(s) then use an end position denoting the start of the next line.
---For example:
---```ts
---{
---    start: { line: 5, character: 23 }
---    end : { line 6, character : 0 }
---}
---```
---@class lsp.Range
---
---The range's start position.
---@field start lsp.Position
---
---The range's end position.
---@field end lsp.Position

---The diagnostic's severity.
---@alias lsp.DiagnosticSeverity
---| 1 # Error
---| 2 # Warning
---| 3 # Information
---| 4 # Hint

---Represents the connection of two locations. Provides additional metadata over normal {@link Location locations},
---including an origin range.
---@class lsp.LocationLink
---
---Span of the origin of this link.
---
---Used as the underlined span for mouse interaction. Defaults to the word range at
---the definition position.
---@field originSelectionRange? lsp.Range
---
---The target resource identifier of this link.
---@field targetUri lsp.DocumentUri
---
---The full target range of this link. If the target for example is a symbol then target range is the
---range enclosing this symbol not including leading/trailing whitespace but everything else
---like comments. This information is typically used to highlight the range in the editor.
---@field targetRange lsp.Range
---
---The range that should be selected and revealed when this link is being followed, e.g the name of a function.
---Must be contained by the `targetRange`. See also `DocumentSymbol#range`
---@field targetSelectionRange lsp.Range

---A parameter literal used in requests to pass a text document and a position inside that
---document.
---@class lsp.TextDocumentPositionParams
---
---The text document.
---@field textDocument lsp.TextDocumentIdentifier
---
---The position inside the text document.
---@field position lsp.Position
