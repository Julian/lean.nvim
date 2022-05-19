local rpc = {}
local a = require'plenary.async'
local util = require'lean._util'
local lsp = require'lean.lsp'
local control = require'plenary.async.control'

---@class RpcRef

---@class Session
---@field client any vim.lsp.client object
---@field uri string
---@field connected boolean
---@field session_id string?
---@field connect_err any | nil
---@field on_connected function
---@field keepalive_timer any
---@field to_release RpcRef[]
---@field release_timer any
local Session = {}
Session.__index = Session

---@param client any vim.lsp.client object
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
  self.keepalive_timer = vim.loop.new_timer()
  self.keepalive_timer:start(20000, 20000, vim.schedule_wrap(function()
    if not self:is_closed() and self.session_id ~= nil then
      self.client.notify('$/lean/rpc/keepAlive', {
        uri = self.uri,
        sessionId = self.session_id,
      })
    end
  end))
  -- Terminate RPC session when document is closed.
  vim.api.nvim_buf_attach(bufnr, false, {
    on_reload = function() self:close_without_releasing() end,
    on_detach = function() self:close_without_releasing() end,
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
  self:release_now{}
  self:close_without_releasing()
end

---@param refs RpcRef[]
function Session:release_now(refs)
  for _, ptr in ipairs(refs) do table.insert(self.to_release, ptr) end
  if #self.to_release == 0 or self:is_closed() then return end
  self.client.notify('$/lean/rpc/release', {
    uri = self.uri,
    sessionId = self.session_id,
    refs = self.to_release,
  })
  self.to_release = {}
end

---@param refs RpcRef[]
function Session:release_deferred(refs)
  for _, ptr in ipairs(refs) do table.insert(self.to_release, ptr) end
  if self.release_timer == nil then
    self.release_timer = vim.defer_fn(function ()
      self.release_timer = nil
      self:release_now{}
    end, 100)
  end
end

---@class TextDocumentIdentifier

---@class LspPosition
---@field line integer
---@field character integer

---@class LspRange
---@field start LspPosition
---@field end LspPosition

---@alias LspSeverity number

---@class TextDocumentPositionParams
---@field textDocument TextDocumentIdentifier
---@field position LspPosition

---@param pos TextDocumentPositionParams
---@param method string
---@return any result
---@return any error
function Session:call(pos, method, params)
  while not self.connected do
    self.on_connected:wait()
  end
  if self.connect_err ~= nil then
    return nil, self.connect_err
  end
  if self:is_closed() then
    return nil, { code = -32900, message = 'LSP server disconnected' }
  end
  local err, result = util.client_a_request(self.client, '$/lean/rpc/call',
    vim.tbl_extend('error', pos, { sessionId = self.session_id, method = method, params = params }))
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
          getmetatable(prox).__gc = function() self:release_deferred{{ p = v }} end
          setmetatable(obj, {[prox] = true})
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
---@result any error
local function connect(bufnr)
  local client = lsp.get_lean4_server(bufnr)
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
    local err, result = util.client_a_request(client, '$/lean/rpc/connect', {uri = uri})
    sess.connected = true
    if err ~= nil then
      sess.connect_err = err
    else
      sess.session_id = result.sessionId
      sess.connect_err = nil
    end
    sess.on_connected:notify_all()
    return err
  end)()
end

---@class Subsession
---@field pos TextDocumentPositionParams
---@field sess Session
local Subsession = {}
Subsession.__index = Subsession

---@param sess Session
---@param pos TextDocumentPositionParams
function Subsession:new(sess, pos)
  return setmetatable({ sess = sess, pos = pos, refs = {} }, self)
end

---@param method string
---@return any result
---@return any error
function Subsession:call(method, params)
  return self.sess:call(self.pos, method, params)
end

function rpc.open(bufnr, params)
  if sessions[bufnr] == nil or sessions[bufnr].connect_err or sessions[bufnr]:is_closed() then
    connect(bufnr)
  end
  return Subsession:new(sessions[bufnr], params)
end

---@alias PlainGoalParams TextDocumentPositionParams

---@alias PlainTermGoalParams TextDocumentPositionParams

---@class InfoWithCtx

---@class CodeToken
---@field info InfoWithCtx

---@class CodeWithInfos
---@field text? string
---@field append? CodeWithInfos[]
---@field tag? {[1]: CodeToken, [2]: CodeWithInfos}

---@class InteractiveHypothesis
---@field names string[]
---@field type CodeWithInfos
---@field val CodeWithInfos | nil

---@class InteractiveGoal
---@field hyps      InteractiveHypothesis[]
---@field type      CodeWithInfos
---@field userName  string | nil

---@class InteractiveGoals
---@field goals InteractiveGoal[]

---@param pos PlainGoalParams
---@return InteractiveGoals | nil
---@return any error
function Subsession:getInteractiveGoals(pos)
  return self:call('Lean.Widget.getInteractiveGoals', pos)
end

---@class InteractiveTermGoal
---@field hyps      InteractiveHypothesis[]
---@field type      CodeWithInfos
---@field range     LspRange

---@param pos PlainTermGoalParams
---@return InteractiveTermGoal | nil
---@return any error
function Subsession:getInteractiveTermGoal(pos)
  return self:call('Lean.Widget.getInteractiveTermGoal', pos)
end

---@class TaggedTextMsgEmbed
---@field text? string
---@field append? TaggedTextMsgEmbed[]
---@field tag? {[1]: MsgEmbed} -- the second field is always the empty string

---@class MsgEmbed
---@field expr? CodeWithInfos
---@field goal? InteractiveGoal
---@field lazyTrace? {[1]: number, [2]: string, [3]: MessageData}

---@class MessageData

---@class InteractiveDiagnostic
---@field range LspRange
---@field fullRange LspRange?
---@field severity LspSeverity?
---@field message TaggedTextMsgEmbed

---@class LineRange
---@field start integer
---@field end integer

---@param lineRange LineRange?
---@return InteractiveDiagnostic[]
---@return any error
function Subsession:getInteractiveDiagnostics(lineRange)
  return self:call('Lean.Widget.getInteractiveDiagnostics', {lineRange = lineRange})
end

---@class InfoPopup
---@field type CodeWithInfos|nil
---@field exprExplicit CodeWithInfos|nil
---@field doc string|nil

---@param i InfoWithCtx
---@return InfoPopup
---@return any error
function Subsession:infoToInteractive(i)
  return self:call('Lean.Widget.InteractiveDiagnostics.infoToInteractive', i)
end

---@param msg MessageData
---@param indent number
---@return TaggedTextMsgEmbed
---@return any error
function Subsession:msgToInteractive(msg, indent)
  return self:call('Lean.Widget.InteractiveDiagnostics.msgToInteractive',
    { msg = msg, indent = indent })
end

---@alias LspDocumentUri string

---@class LspLocationLink
---@field originSelectionRange? LspRange
---@field targetUri LspDocumentUri
---@field targetRange LspRange
---@field targetSelectionRange LspRange

---@alias GoToKind 'declaration'|'definition'|'type'

---@param kind GoToKind
---@param info InfoWithCtx
---@return LspLocationLink[]
---@return any error
function Subsession:getGoToLocation(kind, info)
  return self:call('Lean.Widget.getGoToLocation', { kind = kind, info = info })
end

return rpc
