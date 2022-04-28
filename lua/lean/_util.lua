-- Stuff that should live in some standard library.
local Job = require('plenary.job')
local a = require('plenary.async')
-- local control = require'plenary.async.control'

local M = { DIAGNOSTIC_SEVERITY = { 'error', 'warning', 'information', 'hint' } }

--- Return an array-like table with a value repeated the given number of times.
function M.tbl_repeat(value, times)
  local result = {}
  for _ = 1, times do table.insert(result, value) end
  return result
end

--- Fetch the diagnostics for all Lean LSP clients from the current buffer.
function M.lean_lsp_diagnostics(opts, bufnr)
  bufnr = bufnr or 0
  opts = opts or {}
  local diagnostics = {}
  for _, client in pairs(vim.lsp.buf_get_clients(bufnr)) do
    if client.name:match('^lean') then
      opts.namespace = vim.lsp.diagnostic.get_namespace(client.id)
      vim.list_extend(diagnostics, vim.diagnostic.get(bufnr, opts))
    end
  end
  return diagnostics
end

--- Create autocmds under the specified group, clearing it first.
---
--- REPLACEME: once neovim/neovim#14661 is merged.
function M.set_augroup(name, autocmds, buffer)
  local buffer_string = buffer and (buffer == 0 and "<buffer>" or string.format("<buffer=%d>", buffer)) or ""
  vim.cmd(string.format([[
    augroup %s
      autocmd! %s * %s
      %s
    augroup END
  ]], name, name, buffer_string, autocmds))
end

---@class CreateBufParams
---@field name string @the name of the new buffer
---@field options table<string, any> @a table of options each suitable for nvim_buf_set_option
---@field listed boolean @see :h nvim_create_buf (default true)
---@field scratch boolean @see :h nvim_create_buf (default false)

---Create a new buffer.
---@param params CreateBufParams @new buffer options
---@return integer: the new `bufnr`
function M.create_buf(params)
  if params.listed == nil then params.listed = true end
  if params.scratch == nil then params.scratch = false end
  local bufnr = vim.api.nvim_create_buf(params.listed, params.scratch)
  for option, value in pairs(params.options or {}) do
    vim.api.nvim_buf_set_option(bufnr, option, value)
  end
  if params.name ~= nil then vim.api.nvim_buf_set_name(bufnr, params.name) end
  return bufnr
end

--- Run a subprocess, blocking on exit, and returning its stdout.
---
--- Unlike `system()`, we don't mix stdout and stderr, and unlike
--- `vim.loop.spawn`, we wait for process exit and collect the output.
--- @return table: the lines of stdout of the exited process
function M.subprocess_check_output(opts, timeout)
  timeout = timeout or 10000

  local job = Job:new(opts)

  job:start()
  if not job:wait(timeout) then return end

  if job.code == 0 then
    return job:result()
  end

  error(string.format(
    "%s exited with non-zero exit status %d.\nstderr contained:\n%s",
    vim.inspect(job.command),
    job.code,
    table.concat(job:stderr_result(), '\n')
  ))
end

local function max_common_indent(str)
  local level = math.huge
  local common_indent = ""
  local len
  for indent in str:gmatch("\n( +)") do
    len = #indent
    if len < level then
      level = len
      common_indent = indent
    end
  end
  return common_indent
end

--- Dedent a multi-line string.
---
--- REPLACEME: plenary.nvim has a version of this but it has odd behavior.
function M.dedent(str)
  str = str:gsub(" +$", ""):gsub("^ +", "") -- remove spaces at start and end
  local prefix = max_common_indent(str)
  return (str:gsub("\n" .. prefix, "\n"):gsub("\n$", ""))
end

function M.load_mappings(mappings, buffer)
  local opts = { noremap = true }
  for mode, mode_mappings in pairs(mappings) do
    for lhs, rhs in pairs(mode_mappings) do
      if buffer then
        vim.api.nvim_buf_set_keymap(buffer, mode, lhs, rhs, opts)
      else
        vim.api.nvim_set_keymap(mode, lhs, rhs, opts)
      end
    end
  end
end

-- from mfussenegger/nvim-lsp-compl@29a81f3
function M.mk_handler(fn)
  return function(...)
    local config_or_client_id = select(4, ...)
    local is_new = type(config_or_client_id) ~= 'number'
    if is_new then
      fn(...)
    else
      local err = select(1, ...)
      local method = select(2, ...)
      local result = select(3, ...)
      local client_id = select(4, ...)
      local bufnr = select(5, ...)
      local config = select(6, ...)
      fn(err, result, {method = method, client_id = client_id, bufnr = bufnr}, config)
    end
  end
end

---@param client any vim.lsp.client
---@param request string LSP request name
---@param params table LSP request parameters
---@return any error
---@return any result
function M.client_a_request(client, request, params)
  return a.wrap(function(handler) return client.request(request, params, M.mk_handler(handler)) end, 1)()
end

-- FIXME: tick locking is disabled for now
-- It is really easy to crash the infoview this way if an exception is not handled.

---Helper to check whether a Ticker has been updated with a new version.
---@class Tick
---@field tick integer The ticker counter at initiatization time.
---@field ticker Ticker The corresponding ticker
local Tick = {}
Tick.__index = Tick

---@param tick integer
---@param ticker Ticker
function Tick:new(tick, ticker)
  return setmetatable({tick = tick, ticker = ticker}, self)
end

function Tick:check()
  -- this tick has been cancelled
  if self.ticker.tick ~= self.tick then
    -- allow waiting ticks to proceed
    -- if self.ticker._lock == self.tick then
    --   self.ticker._lock = false
    --   self.ticker.lock_var:notify_all()
    -- end
    return false
  end

  return true
end

---A ticker allows outdated computations to cancel themselves.
---The ticker maintains an internal counter,
---which is incremented whenever a new computation is started.
---The related Tick class wraps a Ticker with
---the counter from the instant the computation was started,
---and is used to query out-of-datedness.
---@class Ticker
---@field tick integer The current tick counter.
local Ticker = {}
Ticker.__index = Ticker

function Ticker:new()
  return setmetatable({tick = 0,
    --_lock = false,
    -- lock_var = control.Condvar.new()
  }, self)
end

-- Updates the tick.
function Ticker:lock()
  -- create new tick
  self.tick = self.tick + 1
  local tick = self.tick

  -- if something else has the lock on this pin, wait for it to acknowlege it has been cancelled
  -- while self._lock do
  --   self.lock_var:wait()
  --
  --   -- if a new tick was created, this is cancelled
  --   if self.tick ~= tick then return false end
  -- end

  -- this is the most recent tick, so we can proceed
  -- self._lock = tick

  return Tick:new(tick, self)
end

-- Release the current tick. Should only be called if certain the tick is up-to-date.
-- luacheck: ignore
function Ticker:release()
  -- self._lock = false
end

-- simple alternative to vim.lsp.util._make_floating_popup_size
function M.make_floating_popup_size(contents)
  local line_widths = {}

  local width = 0
  for i, line in ipairs(contents) do
    -- TODO(ashkan) use nvim_strdisplaywidth if/when that is introduced.
    line_widths[i] = vim.fn.strdisplaywidth(line)
    width = math.max(line_widths[i], width)
  end

  local height = #contents

  return width, height
end

M.Tick = Tick
M.Ticker = Ticker

--- List workspace folders.
--- Backport from https://github.com/neovim/neovim/pull/15059
function M.list_workspace_folders()
  local workspace_folders = {}
  for _, client in pairs(vim.lsp.buf_get_clients()) do
    for _, folder in pairs(client.workspaceFolders) do
      table.insert(workspace_folders, folder.name)
    end
  end
  return workspace_folders
end

---@class UIParams
---@field filename string
---@field row number
---@field col number

--- Check that the given position parameters are valid given the buffer they correspond to.
---@param params UIParams @parameters to verify
---@return boolean
function M.position_params_valid(params)
  local bufnr = vim.fn.bufnr(params.filename)
  if bufnr == -1 then return false end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)

  local line = params.row + 1
  local col = params.col + 1

  if line > #lines then return false end

  if col > #lines[line] then return false end

  return true
end

function M.make_position_params()
  local buf = vim.api.nvim_win_get_buf(0)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1

  return { filename = vim.api.nvim_buf_get_name(buf), row = row, col = col }
end

M.wait_timer = a.wrap(function(timeout, handler) vim.defer_fn(handler, timeout) end, 2)

--- Utility function for getting the encoding of the first LSP client on the given buffer.
---@param bufnr number buffer handle or 0 for current, defaults to current
---@returns string encoding first client if there is one, nil otherwise
function M._get_offset_encoding(bufnr)
  -- TODO: Can this be removed (or removed once 0.6 support is dropped)?
  for _, client in pairs(vim.lsp.buf_get_clients(bufnr)) do
    return client.offset_encoding or "utf-16"
  end
end

return M
