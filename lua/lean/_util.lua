-- Stuff that should live in some standard library.
local Job = require("plenary.job")
local a = require("plenary.async")
local control = require'plenary.async.control'

local M = {}

--- Return an array-like table with a value repeated the given number of times.
---
--- Will hopefully move upstream, see neovim/neovim#14919.
function M.tbl_repeat(value, times)
  local result = {}
  for _ = 1, times do table.insert(result, value) end
  return result
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

function M.uri_to_existing_bufnr(uri)
  local path = vim.uri_to_fname(uri)
  local bufnr = vim.fn.bufnr(path)
  if vim.fn.bufnr ~= -1 then return bufnr end
  return nil
end

-- Lua 5.1 workaround copied from stackoverflow.com/questions/27426704 !!!
function M.setmt__gc(t, mt)
  -- luacheck: ignore
  local prox = newproxy(true)
  getmetatable(prox).__gc = function() mt.__gc(t) end
  t[prox] = true
  return setmetatable(t, mt)
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

function M.wrap_handler(other_handler, handler)
  return function(...)
    other_handler(...)
    handler(...)
  end
end

M.wait_timer = a.wrap(vim.loop.timer_start, 4)

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

-- from mfussenegger/nvim-lsp-compl@29a81f3
function M.request(bufnr, method, params, handler)
  return vim.lsp.buf_request(bufnr, method, params, M.mk_handler(handler))
end

M.a_request = a.wrap(M.request, 4)

local Tick = {}
Tick.__index = Tick

function Tick:new(tick, ticker)
  return setmetatable({tick = tick, ticker = ticker}, self)
end

function Tick:check()
  -- this tick has been cancelled
  if self.ticker.tick ~= self.tick then
    -- allow waiting ticks to proceed
    if self.ticker._lock == self.tick then
      self.ticker._lock = false
      self.ticker.lock_var:notify_all()
    end
    return false
  end

  return true
end

local Ticker = {}
Ticker.__index = Ticker

function Ticker:new()
  return setmetatable({tick = 0, _lock = false, lock_var = control.Condvar.new()}, self)
end

-- Updates the tick if necessary.
function Ticker:lock()
  -- create new tick
  self.tick = self.tick + 1
  local tick = self.tick

  -- if something else has the lock on this pin, wait for it to acknowlege it has been cancelled
  while self._lock do
    self.lock_var:wait()

    -- if a new tick was created, this is cancelled
    if self.tick ~= tick then return false end
  end

  -- this is the most recent tick, so we can proceed
  self._lock = tick

  return Tick:new(tick, self)
end

-- Release the current tick. Should only be called if certain the tick is up-to-date.
function Ticker:release(tick)
  -- don't free the lock if this tick came from a parent context
  if tick then return end

  self._lock = false
end

M.Tick = Tick
M.Ticker = Ticker

return M
