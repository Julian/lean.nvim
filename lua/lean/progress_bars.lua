local progress = require 'lean.progress'

local progress_bars = {}
local options = { priority = 10, character = '│' }
options._DEFAULTS = vim.deepcopy(options)

local sign_group_name = 'leanProgressBar'
local sign_name = 'leanProgressBar'

local sign_ns = vim.api.nvim_create_namespace 'lean.progress'
vim.diagnostic.config({ virtual_text = false, virtual_lines = false }, sign_ns)

local function _update(bufnr)
  vim.fn.sign_unplace(sign_group_name, { buffer = bufnr })
  local diagnostics = {}

  for _, proc_info in ipairs(progress.proc_infos[vim.uri_from_bufnr(bufnr)]) do
    local start_line = proc_info.range.start.line + 1
    local end_line = proc_info.range['end'].line + 1

    for line = start_line, end_line do
      vim.fn.sign_place(0, sign_group_name, sign_group_name, bufnr, {
        lnum = line,
        priority = options.priority,
      })
    end
  end
  vim.diagnostic.set(sign_ns, 0, vim.tbl_values(diagnostics))
end

-- Table from bufnr to timer object.
local timers = {}

function progress_bars.update(params)
  if not progress_bars.enabled then
    return
  end
  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  if timers[bufnr] == nil then
    timers[bufnr] = vim.defer_fn(function()
      timers[bufnr] = nil
      -- In case the buffer was unloaded in between the scheduled update
      if vim.api.nvim_buf_is_loaded(bufnr) then
        _update(bufnr)
      end
    end, 100)
  end
end

function progress_bars.enable(opts)
  options = vim.tbl_extend('force', options, opts)

  vim.fn.sign_define(sign_name, {
    text = options.character,
    texthl = 'leanProgressBar',
  })
  progress_bars.enabled = true
end

return progress_bars
