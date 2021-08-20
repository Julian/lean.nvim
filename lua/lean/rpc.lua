local rpc = {}
local lsp = require'plenary.async.lsp'
local util = require'lean._util'
local control = require'plenary.async.control'

---@class RpcRef

---@class Session
---@field bufnr number
---@field uri string
---@field closed boolean
---@field on_connected function
---@field keepalive_timer any
local Session = {}
Session.__index = Session

---@param bufnr number
---@param uri string
---@return Session
function Session:new(bufnr, uri)
  self = setmetatable({
    bufnr = bufnr,
    uri = uri,
    session_id = nil,
    closed = false,
    on_connected = control.Condvar.new(),
  }, self)
  self.keepalive_timer = vim.loop.new_timer()
  self.keepalive_timer:start(20000, 20000, vim.schedule_wrap(function()
    if self.session_id ~= nil then
      vim.lsp.buf_notify(self.bufnr, '$/lean/rpc/keepAlive', {
        uri = self.uri,
        sessionId = self.session_id,
      })
    end
  end))
  return self
end

function Session:close()
  self.keepalive_timer:close()
end

---@param session_id string
function Session:connected(session_id)
  self.session_id = session_id
  self.on_connected:notify_all()
end

---@param refs RpcRef[]
function Session:release(refs)
  if self.closed or #refs == 0 then return end
  vim.lsp.buf_notify(self.bufnr, '$/lean/rpc/release', {
    uri = self.uri,
    sessionId = self.session_id,
    refs = refs,
  })
end

---@class TextDocumentPositionParams

---@param pos TextDocumentPositionParams
---@param method string
---@return any result
---@return any error
function Session:call(pos, method, params)
  if self.session_id == nil then
    self.on_connected:wait()
  end
  local err, _, result = lsp.buf_request(self.bufnr, '$/lean/rpc/call',
    vim.tbl_extend('error', pos, { sessionId = self.session_id, method = method, params = params }))
  if err ~= nil and err.code == -32900 then
    self.closed = true
  end
  return result, err
end

--- Map from bufnr to Session object.
---@type table<number, Session>
local sessions = {}

---@param bufnr number
local function connect(bufnr)
  local uri = vim.uri_from_bufnr(bufnr)
  sessions[bufnr] = Session:new(bufnr, uri)
  vim.lsp.buf_notify(bufnr, '$/lean/rpc/connect', {uri = uri})
end
vim.lsp.handlers['$/lean/rpc/connected'] = function(err, _, params, _, _, _)
  if err ~= nil then return end
  local bufnr = util.uri_to_existing_bufnr(params.uri)
  if not bufnr then return end
  sessions[bufnr]:connected(params.sessionId)
end

---@class Subsession
---@field refs table<string, RpcRef>
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
  local function register(obj)
    if type(obj) == 'table' then
      for k, v in pairs(obj) do
        if k == 'p' and type(v) ~= 'table' then
          self.refs[v] = {p = v}
        else
          register(v)
        end
      end
    end
  end
  local res, err = self.sess:call(self.pos, method, params)
  register(res)
  return res, err
end

function Subsession:close()
  if self.sess.closed then return end
  local refs = {}
  for _, ref in pairs(self.refs) do
    table.insert(refs, ref)
  end
  self.sess:release(refs)
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

---@class CodeWithInfos
---@field text? string
---@field append? CodeWithInfos[]
---@field tag? {[1]: InfoWithCtx, [2]: CodeWithInfos}

---@class InteractiveHypothesis
---@field names string
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
  return self:call('`Lean.Widget.getInteractiveGoals', pos)
end

---@param pos PlainTermGoalParams
---@return InteractiveGoal | nil
---@return any error
function Subsession:getInteractiveTermGoal(pos)
  return self:call('`Lean.Widget.getInteractiveTermGoal', pos)
end

return rpc
