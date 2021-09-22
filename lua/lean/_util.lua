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

function M.wrap_handler(other_handler, handler)
  return function(...)
    other_handler(...)
    handler(...)
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

-- from mfussenegger/nvim-lsp-compl@29a81f3
function M.request(bufnr, method, params, handler)
  return vim.lsp.buf_request(bufnr, method, params, M.mk_handler(handler))
end

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

return M
