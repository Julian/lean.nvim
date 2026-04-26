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

---A ring buffer stand-in that silently discards pushes and iterates to nothing.
---@type vim.Ringbuf<SessionCallRecord>
local EMPTY_RINGBUF = setmetatable({ push = function() end }, {
  __call = function() end,
})

--- Lean LSP/JSON-RPC error codes that indicate the RPC session is dead.
--- See Lean/Data/JsonRpc.lean for the full set.
local RPC_NEEDS_RECONNECT = -32900
local CONTENT_MODIFIED = -32801
local WORKER_EXITED = -32901
local WORKER_CRASHED = -32902

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

---A single RPC request record, stored in the session's history ring buffer.
---@class SessionCallRecord
---@field method string the RPC method that was called
---@field start_ns integer hrtime when the call was attempted
---@field duration_ns integer elapsed nanoseconds (0 for calls that never reached the server)
---@field error? LspError the error, if the call failed

---Counters and timing for an RPC session, always collected.
---
---When `debug.rpc_history` is enabled, `history` additionally contains
---a bounded ring buffer of individual request records.
---@class SessionMetrics
---@field created_at integer hrtime when the session was created
---@field call_count integer total calls attempted (including errors)
---@field error_count integer calls that returned an error
---@field errors_by_code table<integer|"unknown", integer> error counts keyed by LSP error code
---@field reconnects integer reconnects performed on this session
---@field total_reconnects integer cumulative reconnects including prior sessions for this URI
---@field total_duration_ns integer sum of durations for calls that reached the server
---@field max_duration_ns integer longest call that reached the server
---@field min_duration_ns integer shortest call that reached the server (0 until the first such call)
---@field connect_duration_ns? integer time spent in the initial $/lean/rpc/connect handshake
---@field history vim.Ringbuf<SessionCallRecord> request history (empty when rpc_history is 0)
local SessionMetrics = {}
SessionMetrics.__index = SessionMetrics

---@param history_size integer
---@return SessionMetrics
function SessionMetrics:new(history_size)
  return setmetatable({
    created_at = vim.uv.hrtime(),
    call_count = 0,
    error_count = 0,
    errors_by_code = {},
    reconnects = 0,
    total_reconnects = 0,
    total_duration_ns = 0,
    max_duration_ns = 0,
    min_duration_ns = 0,
    history = history_size > 0 and vim.ringbuf(history_size) or EMPTY_RINGBUF,
  }, self)
end

---Record an error for a call that did not reach the server.
---@param method string
---@param err LspError
---@return nil
---@return LspError
function SessionMetrics:record_error(method, err)
  self.call_count = self.call_count + 1
  self.error_count = self.error_count + 1
  local code = type(err) == 'table' and err.code
  local code_key = code or 'unknown'
  self.errors_by_code[code_key] = (self.errors_by_code[code_key] or 0) + 1
  self.history:push { method = method, start_ns = vim.uv.hrtime(), duration_ns = 0, error = err }
  return nil, err
end

---Record a completed call that reached the server.
---@param method string
---@param start_ns integer
---@param elapsed integer
---@param err? LspError
function SessionMetrics:record_call(method, start_ns, elapsed, err)
  self.call_count = self.call_count + 1
  self.total_duration_ns = self.total_duration_ns + elapsed
  if elapsed > self.max_duration_ns then
    self.max_duration_ns = elapsed
  end
  if self.min_duration_ns == 0 or elapsed < self.min_duration_ns then
    self.min_duration_ns = elapsed
  end

  if err ~= nil then
    self.error_count = self.error_count + 1
    local code = type(err) == 'table' and err.code
    local code_key = code or 'unknown'
    self.errors_by_code[code_key] = (self.errors_by_code[code_key] or 0) + 1
  end

  self.history:push { method = method, start_ns = start_ns, duration_ns = elapsed, error = err }
end

---Record a successful connection handshake.
---@param duration_ns integer
function SessionMetrics:record_connect(duration_ns)
  self.connect_duration_ns = duration_ns
end

---Record that this session was reached via a reconnection.
---@param prev_total integer total_reconnects from the prior session
function SessionMetrics:record_reconnect(prev_total)
  self.reconnects = self.reconnects + 1
  self.total_reconnects = prev_total + 1
end

---Carry forward the cumulative reconnect count from a prior session.
---@param prev_total integer total_reconnects from the prior session
function SessionMetrics:carry_reconnects(prev_total)
  self.total_reconnects = math.max(self.total_reconnects, prev_total)
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
---@field metrics SessionMetrics
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
    metrics = SessionMetrics:new(require 'lean.config'().debug.rpc_history),
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
  if self.release_timer then
    self.release_timer:close()
    self.release_timer = nil
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
    return self.metrics:record_error(method, self.connect_err)
  end

  if not Buffer:from_uri(pos.textDocument.uri):is_loaded() then
    self:close_without_releasing()
  end

  if self:is_closed() then
    return self.metrics:record_error(
      method,
      { code = RPC_NEEDS_RECONNECT, message = 'RPC session is closed' }
    )
  end
  log:trace { message = 'calling RPC method', method = method, params = params }
  local start_ns = vim.uv.hrtime()
  local err, result = client_request(
    self.client,
    '$/lean/rpc/call',
    vim.tbl_extend('error', pos, { sessionId = self.session_id, method = method, params = params })
  )
  local elapsed = vim.uv.hrtime() - start_ns
  self.metrics:record_call(method, start_ns, elapsed, err)

  if err ~= nil then
    local code = type(err) == 'table' and err.code
    if
      code == RPC_NEEDS_RECONNECT
      or code == CONTENT_MODIFIED
      or code == WORKER_EXITED
      or code == WORKER_CRASHED
    then
      self:close_without_releasing()
    end
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
    local level = self:is_closed() and 'debug' or 'error'
    log[level](log, {
      message = 'RPC error',
      method = method,
      params = params,
      error = err,
      result = result,
    })
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
    local connect_start = vim.uv.hrtime()
    local err, result = client_request(client, '$/lean/rpc/connect', { uri = uri })
    sess.metrics:record_connect(vim.uv.hrtime() - connect_start)
    sess.connected = true
    if err ~= nil then
      sess.connect_err = err
      sess:close_without_releasing()
    else
      sess.session_id = result.sessionId
      sess.connect_err = nil
    end
    sess.on_connected.set()
  end)
end

---An RPC session bound to a specific position within a document.
---
---If the underlying connection has died or failed to connect, each call
---will automatically reconnect, retrying up to `max_attempts` times.
---@class ReconnectingSubsession
---@field pos lsp.TextDocumentPositionParams
---@field sess Session the underlying session; may be swapped on reconnect
---@field private max_attempts integer
local ReconnectingSubsession = {}
ReconnectingSubsession.__index = ReconnectingSubsession

---@param sess Session
---@param pos lsp.TextDocumentPositionParams
---@param max_attempts? integer maximum reconnection attempts per call (default 3)
function ReconnectingSubsession:new(sess, pos, max_attempts)
  return setmetatable({ sess = sess, pos = pos, max_attempts = max_attempts or 3 }, self)
end

---@param method string
---@param params any
---@return any result
---@return LspError error
function ReconnectingSubsession:call(method, params)
  local result, err
  for _ = 1, self.max_attempts do
    result, err = self.sess:call(self.pos, method, params)
    if not err then
      return result
    end
    -- Reconnect if the session is dead or failed to connect.
    local uri = self.pos.textDocument.uri
    if self.sess:is_closed() or self.sess.connect_err then
      local prev_total = self.sess.metrics.total_reconnects
      -- Another caller may have already reconnected; adopt the current
      -- session when it is still alive rather than replacing it.
      if sessions[uri] ~= self.sess and not sessions[uri]:is_closed() then
        self.sess = sessions[uri]
        self.sess.metrics:carry_reconnects(prev_total)
      else
        log:debug { message = 'reconnecting RPC session', uri = uri, method = method, error = err }
        connect(uri)
        self.sess = sessions[uri]
        self.sess.metrics:record_reconnect(prev_total)
      end
    else
      break
    end
  end
  return result, err
end

---Open an RPC session.
---@param params lsp.TextDocumentPositionParams
---@return ReconnectingSubsession
function rpc.open(params)
  local uri = params.textDocument.uri
  if sessions[uri] == nil or sessions[uri].connect_err or sessions[uri]:is_closed() then
    connect(uri)
  end
  return ReconnectingSubsession:new(sessions[uri], params)
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
function ReconnectingSubsession:getInteractiveGoals()
  return self:call('Lean.Widget.getInteractiveGoals', self.pos)
end

---@return InteractiveTermGoal
---@return LspError error
function ReconnectingSubsession:getInteractiveTermGoal()
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
function ReconnectingSubsession:getInteractiveDiagnostics(lineRange)
  return self:call('Lean.Widget.getInteractiveDiagnostics', { lineRange = lineRange })
end

---@param msg MessageData
---@param indent number
---@return TaggedText.MsgEmbed
---@return LspError error
function ReconnectingSubsession:msgToInteractive(msg, indent)
  return self:call(
    'Lean.Widget.InteractiveDiagnostics.msgToInteractive',
    { msg = msg, indent = indent }
  )
end

---@param children LazyTraceChildren
---@return TaggedText.MsgEmbed[]
---@return LspError error
function ReconnectingSubsession:lazyTraceChildrenToInteractive(children)
  return self:call('Lean.Widget.lazyTraceChildrenToInteractive', children)
end

---@param info InfoWithCtx
---@return InfoPopup
---@return LspError error
function ReconnectingSubsession:infoToInteractive(info)
  return self:call('Lean.Widget.InteractiveDiagnostics.infoToInteractive', info)
end

---@alias GoToKind 'declaration' | 'definition' | 'type'

---@param kind GoToKind
---@param info InfoWithCtx
---@return lsp.LocationLink[]
---@return LspError error
function ReconnectingSubsession:getGoToLocation(kind, info)
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
function ReconnectingSubsession:getWidgets()
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
function ReconnectingSubsession:getWidgetSource(hash)
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

---Highlight matches of a query string within a diagnostic message.
---
---The input is a regular TaggedText<MsgEmbed> diagnostic message.
---The result is a TaggedText<HighlightedMsgEmbed> where matching portions
---are tagged with 'highlighted'.
---@param query string
---@param msg TaggedText.MsgEmbed
---@return TaggedText.HighlightedMsgEmbed
---@return LspError error
function ReconnectingSubsession:highlightMatches(query, msg)
  return self:call('Lean.Widget.highlightMatches', { query = query, msg = msg })
end

---@class rpc.SessionInfo
---@field metrics SessionMetrics
---@field alive boolean whether the session is still connected

---Return info for all sessions, keyed by URI.
---@return table<string, rpc.SessionInfo>
function rpc.sessions()
  return vim.iter(sessions):fold({}, function(result, uri, sess)
    result[uri] = { metrics = sess.metrics, alive = sess.client ~= nil }
    return result
  end)
end

---Return the request history for a URI's session, or nil if unknown.
---@param uri string
---@return SessionCallRecord[]?
function rpc.history(uri)
  local sess = sessions[uri]
  if not sess then
    return nil
  end
  return vim.iter(sess.metrics.history):totable()
end

return rpc
