local progress = require('lean.progress')

local progress_bars = {}
local options = {  priority = 10, character = '⋯' }
options._DEFAULTS = vim.deepcopy(options)

local sign_group_name = 'leanSignProgress'
local sign_name = 'leanSignProgress'

local sign_ns = vim.api.nvim_create_namespace('lean.progress')
vim.diagnostic.config({ virtual_text = false }, sign_ns)

local function _update(bufnr)
  vim.fn.sign_unplace(sign_group_name, { buffer = bufnr })
  local diagnostics = {}

  for _, proc_info in ipairs(progress.proc_infos[vim.uri_from_bufnr(bufnr)]) do
    local start_line = proc_info.range.start.line + 1
    local end_line = proc_info.range['end'].line + 1

    -- Don't show multiple diagnostics if there are overlapping ranges (which
    -- seems to happen in Lean 3 at least), and here we don't shift by 1.
    if not diagnostics[start_line] then
      diagnostics[start_line] = {
        lnum = proc_info.range.start.line,
        col = 0,
        message = "Processing...",
        severity = vim.diagnostic.severity.INFO,
      }
    end

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
  if not progress_bars.enabled then return end
  -- TODO FIXME can potentially create new buffer
  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)

  if timers[bufnr] == nil then
    timers[bufnr] = vim.defer_fn(function ()
      timers[bufnr] = nil
      _update(bufnr)
    end, 100)
  end
end

function progress_bars.enable(opts)
  options = vim.tbl_extend("force", options, opts)

  vim.fn.sign_define(sign_name, {
    text = options.character,
    texthl = 'leanSignProgress',
  })
  vim.cmd.hi('def leanSignProgress guifg=orange ctermfg=215')
  progress_bars.enabled = true
end

return progress_bars
