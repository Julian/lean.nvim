local Buffer = require 'std.nvim.buffer'

local progress = require 'lean.progress'

local progress_bars = {}
local options = { priority = 10, character = '│' }
options._DEFAULTS = vim.deepcopy(options)

local sign_group_name = 'leanProgressBar'
local sign_name = 'leanProgressBar'

local sign_ns = vim.api.nvim_create_namespace 'lean.progress'
vim.diagnostic.config({ virtual_text = false, virtual_lines = false }, sign_ns)

---@param buffer Buffer
local function _update(buffer)
  vim.fn.sign_unplace(sign_group_name, { buffer = buffer.bufnr })
  local diagnostics = {}

  for _, proc_info in ipairs(progress.proc_infos[buffer:uri()]) do
    local start_line = proc_info.range.start.line + 1
    local end_line = proc_info.range['end'].line + 1

    for line = start_line, end_line do
      vim.fn.sign_place(0, sign_group_name, sign_group_name, buffer.bufnr, {
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
  local buffer = Buffer:from_uri(params.textDocument.uri)
  if not buffer:is_loaded() then
    return
  end

  if timers[buffer.bufnr] == nil then
    timers[buffer.bufnr] = vim.defer_fn(function()
      timers[buffer.bufnr] = nil
      -- In case the buffer was unloaded in between the scheduled update
      if buffer:is_loaded() then
        _update(buffer)
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
