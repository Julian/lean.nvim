---@mod lean.rpc RPC

---@brief [[
--- Low-level RPC with the Lean server.
---
--- See Lean/Server/FileWorker/WidgetRequests.lean for the Lean side of many of
--- the below data structures.
---@brief ]]

local Buffer = require 'std.nvim.buffer'
local async = require 'std.async'

local log = require 'lean.log'
local lsp = require 'lean.lsp'

---@param client vim.lsp.Client
---@param request string LSP request name
---@param params table LSP request parameters
---@return any error
---@return any result
local function client_request(client, request, params)
  return async.wrap(function(handler)
    return client:request(request, params, handler)
  end, 1)()
end

local rpc = {}

---@class RpcRef

---The JSON key used to encode RPC references.
---In wire format v0, this is `"p"`; in v1, it is `"__rpcref"`.
---@alias RpcRefKey '"p"' | '"__rpcref"'

---Determine the RPC reference field name from the server's capabilities.
---@param client vim.lsp.Client?
---@return string ref_key
local function ref_key_for(client)
  local rpc_provider =
    vim.tbl_get(client and client.server_capabilities or {}, 'experimental', 'rpcProvider')
  local wire_format = rpc_provider and rpc_provider.rpcWireFormat
  if wire_format == 'v1' then
    return '__rpcref'
  end
  return 'p'
end

---@class Session
---@field client? vim.lsp.Client
---@field uri string
---@field ref_key RpcRefKey the JSON key for RPC references (`"p"` or `"__rpcref"`)
---@field connected? boolean
---@field session_id? integer
---@field connect_err? LspError
---@field on_connected std.async.Event
---@field keepalive_timer? uv_timer_t
---@field to_release RpcRef[]
---@field release_timer? uv_timer_t
local Session = {}
Session.__index = Session

---How long to wait between sending Lean's RPC keep-alive notifications.
---
---`Lean.Server.FileWorker.Utils` defines this to be 30000(ms), i.e. it must be
---sent as least that often, so we pick a number less than that.
---
---It so happens the VSCode extension (in `src/infoview.ts`) uses 10000 but
---it isn't clear why it would matter to send it even more often, as long as
---it's sent more often than the 30s deadline.
local KEEPALIVE_PERIOD_MS = 20000

---@param client vim.lsp.Client
---@param buffer Buffer
---@param uri string
---@return Session
function Session:new(client, buffer, uri)
  self = setmetatable({
    client = client,
    uri = uri,
    ref_key = ref_key_for(client),
    session_id = nil,
    connected = nil,
    connect_err = nil,
    on_connected = async.event(),
    to_release = {},
    release_timer = nil,
  }, self)
  self.keepalive_timer = vim.uv.new_timer()
  self.keepalive_timer:start(
    KEEPALIVE_PERIOD_MS,
    KEEPALIVE_PERIOD_MS,
    vim.schedule_wrap(function()
      if not self:is_closed() and self.session_id ~= nil then
        self.client:notify('$/lean/rpc/keepAlive', {
          uri = self.uri,
          sessionId = self.session_id,
        })
      end
    end)
  )
  -- Terminate RPC session when document is closed.
  buffer:attach {
    on_reload = function()
      self:close_without_releasing()
    end,
    on_detach = function()
      self:close_without_releasing()
    end,
  }
  return self
end

---NOTE: has the side effect of closing the session if the client has stopped.
function Session:is_closed()
  if self.client and self.client:is_stopped() then
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

---A notification to release remote references. Should be sent by the client when it no longer needs
---`RpcRef`s it has previously received from the server. Not doing so is safe but will leak memory.
---@class RpcReleaseParams
---@field uri lsp.DocumentUri
---@field sessionId integer
---@field refs RpcRef[]

---@param refs RpcRef[]
function Session:release_now(refs)
  vim.list_extend(self.to_release, refs)
  if #self.to_release == 0 or self:is_closed() then
    return
  end

  log:debug {
    message = 'releasing RPC refs',
    uri = self.uri,
    refs = self.to_release,
  }

  ---@type RpcReleaseParams
  local params = {
    uri = self.uri,
    sessionId = self.session_id,
    refs = self.to_release,
  }
  local succeeded = pcall(self.client.notify, self.client, '$/lean/rpc/release', params)
  if not succeeded then
    log:warning {
      message = 'unable to release RPC refs, which leaks a bit of memory',
      params = params,
    }
  end
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
---@param params any
---@return any result
---@return LspError error
function Session:call(pos, method, params)
  while not self.connected do
    self.on_connected.wait()
  end
  if self.connect_err ~= nil then
    return nil, self.connect_err
  end

  if not Buffer:from_uri(pos.textDocument.uri):is_loaded() then
    self:close_without_releasing()
  end

  if self:is_closed() then
    return nil, { code = -32900, message = 'LSP server disconnected' }
  end
  log:trace { message = 'calling RPC method', method = method, params = params }
  local err, result = client_request(
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
        if k == self.ref_key and type(v) ~= 'table' then
          -- Lua 5.1 workaround for unsupported __gc on tables
          -- luacheck: ignore
          local prox = newproxy(true)
          local release_ref = { [self.ref_key] = v }
          getmetatable(prox).__gc = function()
            self:release_deferred { release_ref }
          end
          setmetatable(obj, { [prox] = true })
        else
          register(v)
        end
      end
    end
  end
  register(result)

  if err then
    log:error {
      message = 'RPC error',
      method = method,
      params = params,
      error = err,
      result = result,
    }
  end
  return result, err
end

---Map from URI to Session object.
---@type table<string, Session>
local sessions = {}

---@param uri string
local function connect(uri)
  local buffer = Buffer:from_uri(uri)
  local client = lsp.client_for(buffer.bufnr)
  local sess = Session:new(client, buffer, uri)
  sessions[uri] = sess
  if client == nil then
    sess.connected = true
    sess.connect_err = 'Lean 4 LSP server not found'
    sess:close_without_releasing()
    return
  end
  async.run(function()
    log:trace { message = 'connecting to RPC', uri = uri }
    local err, result = client_request(client, '$/lean/rpc/connect', { uri = uri })
    sess.connected = true
    if err ~= nil then
      sess.connect_err = err
    else
      sess.session_id = result.sessionId
      sess.connect_err = nil
    end
    sess.on_connected.set()
  end)
end

---@class Subsession
---@field pos lsp.TextDocumentPositionParams
---@field sess Session
local Subsession = {}
Subsession.__index = Subsession

---@param sess Session
---@param pos lsp.TextDocumentPositionParams
function Subsession:new(sess, pos)
  return setmetatable({ sess = sess, pos = pos }, self)
end

---@param method string
---@param params any
---@return any result
---@return LspError error
function Subsession:call(method, params)
  return self.sess:call(self.pos, method, params)
end

---Open an RPC session.
---@param params lsp.TextDocumentPositionParams
---@return Subsession
function rpc.open(params)
  local uri = params.textDocument.uri
  if sessions[uri] == nil or sessions[uri].connect_err or sessions[uri]:is_closed() then
    connect(uri)
  end
  return Subsession:new(sessions[uri], params)
end

---This type is for internal use in the infoview/LSP. It should not be used in user widgets.
---@class InfoWithCtx

---@alias SubexprPos string

---@class InfoPopup
---@field type CodeWithInfos?
---@field exprExplicit CodeWithInfos?
---@field doc string?

---@alias FVarId string
---@alias MVarId string

---In the infoview, if multiple hypotheses `h₁`, `h₂` have the same type `α`,
---they are rendered as `h₁ h₂ : α`. We call this a 'hypothesis bundle'.
---@class InteractiveHypothesisBundle
---@field names string[] The user-friendly name for each hypothesis.
---@field fvarIds? FVarId[] The ids for each variable. Should have the same length as `names`.
---@field type CodeWithInfos
---@field val? CodeWithInfos The value, in the case the hypothesis is a `let`-binder.
---@field isInstance? boolean The hypothesis is a typeclass instance.
---@field isType? boolean The hypothesis is a type.
---@field isInserted? boolean If true, the hypothesis was not present on the previous tactic state.
---                           Only present in tactic-mode goals.
---@field isRemoved? boolean If true, the hypothesis will be removed in the next tactic state.
---                           Only present in tactic-mode goals.

---@class ContextInfo
---@class TermInfo

---The shared parts of interactive term-mode and tactic-mode goals.
---@class InteractiveGoalCore
---@field hyps InteractiveHypothesisBundle[]
---@field type CodeWithInfos The target type.
---@field ctx ContextInfo Metavariable context that the goal is well-typed in.

---An interactive tactic-mode goal.
---@class InteractiveGoal: InteractiveGoalCore
---@field userName? string The name `foo` in `case foo`, if any.
---@field goalPrefix? string The symbol to display before the target type.
---                          Usually `⊢ ` but `conv` goals use `∣ ` and it could be extended.
---@field mvarId MVarId Identifies the goal (ie with the unique name of the MVar that it is a goal for.)
---@field isInserted? boolean If true, the goal was not present on the previous tactic state.
---@field isRemoved? boolean If true, the goal will be removed on the next tactic state.

---An interactive term-mode goal.
---@class InteractiveTermGoal
---@field range? lsp.Range Syntactic range of the term.
---@field term TermInfo Information about the term whose type is the term-mode goal.

---@class InteractiveGoals
---@field goals InteractiveGoal[]

---@return InteractiveGoals goals
---@return LspError error
function Subsession:getInteractiveGoals()
  return self:call('Lean.Widget.getInteractiveGoals', self.pos)
end

---@return InteractiveTermGoal
---@return LspError error
function Subsession:getInteractiveTermGoal()
  return self:call('Lean.Widget.getInteractiveTermGoal', self.pos)
end

---@class StrictTraceChildrenEmbed
---@field strict TaggedText.MsgEmbed[]

---@class LazyTraceChildren

---@class LazyTraceChildrenEmbed
---@field lazy LazyTraceChildren

---@class WidgetEmbed
---@field wi UserWidgetInstance A widget instance.
---@field alt TaggedText.MsgEmbed a fallback rendering of the widget

---@class TraceEmbed
---@field indent integer
---@field cls string
---@field msg TaggedText.MsgEmbed
---@field collapsed boolean
---@field children StrictTraceChildrenEmbed | LazyTraceChildrenEmbed

---@class MessageData

---@alias InteractiveDiagnostic DiagnosticWith<TaggedText.MsgEmbed>

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
---@return TaggedText.MsgEmbed
---@return LspError error
function Subsession:msgToInteractive(msg, indent)
  return self:call(
    'Lean.Widget.InteractiveDiagnostics.msgToInteractive',
    { msg = msg, indent = indent }
  )
end

---@param children LazyTraceChildren
---@return TaggedText.MsgEmbed[]
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
---@field props any JSON object to be passed as props to the component
---@field range lsp.Range

---@class UserWidgets
---@field widgets UserWidgetInstance[]

---@return UserWidgets
---@return LspError error
function Subsession:getWidgets()
  return self:call('Lean.Widget.getWidgets', self.pos.position)
end

---@class WidgetSource
---@field sourcetext string JavaScript sourcecode.
---                         Should be a plain JavaScript ESModule whose default
---                         export is the component to render.

---Get the static JS source for a widget.
---@param hash string
---@return WidgetSource
---@return LspError error
function Subsession:getWidgetSource(hash)
  return self:call('Lean.Widget.getWidgetSource', { pos = self.pos.position, hash = hash })
end

---@class rpc.GoalLocationHyp
---@field hyp GoalLocationHyp

---@class rpc.GoalLocationHypType
---@field hypType GoalLocationHypType

---@class rpc.GoalLocationHypValue
---@field hypValue GoalLocationHypValue

---@class rpc.GoalLocationTarget
---@field target GoalLocationTarget

---@alias rpc.GoalLocation
---  | rpc.GoalLocationHyp
---  | rpc.GoalLocationHypType
---  | rpc.GoalLocationHypValue
---  | rpc.GoalLocationTarget

---@class GoalsLocation
---@field mvarId MVarId
---@field loc rpc.GoalLocation

---@class LspErrorCodeMessage
---@field code lsp.ErrorCodes
---@field message? string

---@alias LspError LspErrorCodeMessage|string

return rpc
