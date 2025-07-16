--- A tiny microbenchmark to time how long it takes before Lean is ready for
--- processing in a specific file.
---
--- Timing info is written to a file named `timing` in the working directory.

local f = io.open('timing', 'w')
if not f then
  error 'Could not open timing file for writing'
end

---Wait until the file is finished or time only when it starts processing?
local wait_until_finished = false

local t0 = vim.uv.hrtime()
local function log_time(label)
  local elapsed = (vim.uv.hrtime() - t0) / 1e9
  f:write(string.format('%s: %.3f\n', label, elapsed))
  f:flush()
end

vim.api.nvim_create_autocmd('Filetype', {
  pattern = 'lean',
  once = true,
  callback = function()
    log_time 'Filetype'
  end,
})
vim.api.nvim_create_autocmd('LspAttach', {
  once = true,
  callback = function()
    log_time 'lsp is ready'
  end,
})
vim.api.nvim_create_autocmd('User', {
  pattern = 'LeanProgressUpdate',
  callback = function()
    local progress = require 'lean.progress'
    local current = progress.at(vim.lsp.util.make_position_params(0, 'utf-16'))
    if current == progress.Kind.processing then
      log_time '$/lean/fileProgress processing'
      if not wait_until_finished then
        vim.cmd.quitall()
      end
    else
      log_time '$/lean/fileProgress finished'
      vim.cmd.quitall()
    end
  end,
})
