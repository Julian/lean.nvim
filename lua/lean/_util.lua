-- Stuff that should live in some standard library.
local Job = require("plenary.job")

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

return M
