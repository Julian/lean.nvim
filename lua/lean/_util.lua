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

function M.after_or_equal(pos, other_pos)
  if pos.line > other_pos.line then return true end
  if pos.line == other_pos.line and pos.character >= other_pos.character then return true end
  return false
end

function M.update_position(pos, changes)
  local new_pos = vim.deepcopy(pos)

  for _, change in pairs(changes) do
    local start_pos = change.range["start"]
    local end_pos = change.range["end"]
    if not M.after_or_equal(new_pos, start_pos) then goto next_change end

    local new_lines = vim.split(change.text, "\n")
    if new_pos.line >= end_pos.line then
      local orig_line_offset = new_pos.line - end_pos.line
      local new_end_line = start_pos.line + (#new_lines - 1)
      new_pos.line = new_end_line + orig_line_offset

      if new_pos.line == end_pos.line then
        -- change range is exclusive, so okay if ==
        if new_pos.character >= end_pos.character then
          local orig_char_offset = new_pos.character - end_pos.character
          local new_end_char = #new_lines == 1 and (start_pos.character + #new_lines[1])
            or #(new_lines[#new_lines])
          new_pos.character = new_end_char + orig_char_offset
        else
          -- within modified range, invalidate
          new_pos = nil
          return new_pos
        end
      end
    else
      -- within modified range, invalidate
      new_pos = nil
      return new_pos
    end
    ::next_change::
  end

  return new_pos
end

return M
