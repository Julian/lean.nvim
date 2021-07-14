-- Stuff that should live in some standard library.

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
function M.subprocess_check_output(cmd, opts, timeout)
  if not timeout then timeout = 10000 end
  local lines, stderr_lines

  opts = vim.tbl_extend(
    "keep", opts or {}, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data) lines = data end,
      on_stderr = function(_, data) stderr_lines = data end
    }
  )

  local job = vim.fn.jobstart(cmd, opts)
  local return_code = vim.fn.jobwait({ job }, timeout)[1]
  local error

  if return_code == 0 then
    return lines
  elseif return_code == -1 then
    error = string.format(
      "%s failed to finish executing within %0.2f seconds.",
      vim.inspect(cmd),
      timeout / 1000
    )
  else
    error = string.format(
      "%s exited with non-zero exit status %d.\nstderr contained:\n%s",
      vim.inspect(cmd),
      return_code,
      table.concat(stderr_lines, '\n')
    )
  end

  vim.api.nvim_err_writeln(error)
end

return M
