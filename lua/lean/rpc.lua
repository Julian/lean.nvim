local rpc = {}
local a = require'plenary.async'
local lsp = require'plenary.async.lsp'
local control = require'plenary.async.control'

---@class RpcRef

---@class Session
---@field client any vim.lsp.client object
---@field uri string
---@field closed boolean
---@field connected boolean
---@field connect_err any | nil
---@field on_connected function
---@field keepalive_timer any
---@field to_release RfcPtr[]
---@field release_timer any
local Session = {}
Session.__index = Session

---@param client any vim.lsp.client object
---@param uri string
---@return Session
function Session:new(client, uri)
  self = setmetatable({
    client = client,
    uri = uri,
    session_id = nil,
    connected = nil,
    connect_err = nil,
    closed = false,
    on_connected = control.Condvar.new(),
    to_release = {},
    release_timer = nil,
  }, self)
  self.keepalive_timer = vim.loop.new_timer()
  self.keepalive_timer:start(20000, 20000, vim.schedule_wrap(function()
    if self.session_id ~= nil and self.client ~= nil then
      self.client.notify('$/lean/rpc/keepAlive', {
        uri = self.uri,
        sessionId = self.session_id,
      })
    end
  end))
  return self
end

function Session:close()
  self:release_now{}
  self.keepalive_timer:close()
  self.closed = true
  self.client = nil
end

---@param refs RpcRef[]
function Session:release_now(refs)
  for _, ptr in ipairs(refs) do table.insert(self.to_release, ptr) end
  if self.closed or #self.to_release == 0 or self.client == nil then return end
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

---@class TextDocumentPositionParams
---@field textDocument TextDocumentIdentifier
---@field position LspPosition

---@param pos TextDocumentPositionParams
---@param method string
---@return any result
---@return any error
function Session:call(pos, method, params)
  if not self.connected then
    self.on_connected:wait()
  end
  if self.connect_err ~= nil then
    return nil, self.connect_err
  end
  local err, _, result = a.wrap(self.client.request, 3)('$/lean/rpc/call',
    vim.tbl_extend('error', pos, { sessionId = self.session_id, method = method, params = params }))
  if err ~= nil and err.code == -32900 then
    self.closed = true
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

--- Finds the vim.lsp.client object for the Lean 4 server associated to the
--- given bufnr.
local function get_lean4_server(bufnr)
  for _, client in pairs(vim.lsp.buf_get_clients(bufnr)) do
    if client.name == 'leanls' then
      return client
    end
  end
end

---@param bufnr number
---@result any error
local function connect(bufnr)
  local client = get_lean4_server(bufnr)
  local uri = vim.uri_from_bufnr(bufnr)
  local sess = Session:new(client, uri)
  sessions[bufnr] = sess
  if client == nil then
    sess.connected = true
    local err = 'Lean 4 LSP server not found'
    sess.connect_err = err
    return err
  end
  a.void(function()
    local err, _, result = lsp.buf_request(bufnr, '$/lean/rpc/connect', {uri = uri})
    sess.connected = true
    if err ~= nil then
      sess.connect_err = err
    else
      sess.session_id = result.sessionId
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

function rpc.open()
  local bufnr = vim.api.nvim_get_current_buf()
  if sessions[bufnr] == nil then
    connect(bufnr)
  elseif sessions[bufnr].closed then
    sessions[bufnr]:close()
    connect(bufnr)
  end
  return Subsession:new(sessions[bufnr], vim.lsp.util.make_position_params())
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
---@return InteractiveGoals
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

return rpc
