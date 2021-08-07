local progress = require('lean.progress')
local M = {}
local options = { _DEFAULTS = { priority = 10, character = '⋯' } }

local progress_sign = 'leanSignProgress'
local sign_ns = 'leanSignProgress'

local function _update(bufnr)
  vim.fn.sign_unplace(sign_ns, { buffer = bufnr })
  for _, proc_info in ipairs(progress.proc_infos[vim.uri_from_bufnr(bufnr)]) do
    local start_line = proc_info.range.start.line + 1
    local end_line = proc_info.range['end'].line + 1
    for line = start_line, end_line do
      vim.fn.sign_place(0, sign_ns, progress_sign, bufnr, {
        lnum = line,
        priority = options.priority,
      })
    end
  end
end

-- Table from bufnr to timer object.
local timers = {}

function M.update(params)
  if not M.enabled then return end
  -- TODO FIXME can potentially create new buffer
  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)

  if timers[bufnr] == nil then
    timers[bufnr] = vim.defer_fn(function ()
      timers[bufnr] = nil
      _update(bufnr)
    end, 100)
  end
end

function M.enable(opts)
  options = vim.tbl_extend("force", options._DEFAULTS, opts)
  vim.fn.sign_define(progress_sign, {
    text = options.character,
    texthl = 'leanSignProgress',
  })
  vim.cmd[[ hi def leanSignProgress guifg=orange ctermfg=215 ]]
  M.enabled = true
end

return M
