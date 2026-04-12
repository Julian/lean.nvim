local Buffer = require 'std.nvim.buffer'

local progress = require 'lean.progress'

local progress_bars = {}
local options = { priority = 10, character = '│' }
options._DEFAULTS = vim.deepcopy(options)

local ns = vim.api.nvim_create_namespace 'lean.progress'

---@param buffer Buffer
local function _update(buffer)
  buffer:clear_namespace(ns)

  for _, proc_info in ipairs(progress.proc_infos[buffer:uri()]) do
    local start_line = proc_info.range.start.line
    local end_line = proc_info.range['end'].line

    for line = start_line, end_line do
      buffer:set_extmark(ns, line, 0, {
        sign_text = options.character,
        sign_hl_group = 'leanProgressBar',
        priority = options.priority,
      })
    end
  end
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
      -- clear() may have already run between the timer firing and this
      -- scheduled callback executing, in which case do nothing.
      if timers[buffer.bufnr] == nil then
        return
      end
      timers[buffer.bufnr] = nil
      -- In case the buffer was unloaded in between the scheduled update
      if buffer:is_loaded() then
        _update(buffer)
      end
    end, 100)
  end
end

---Clear all progress bar signs from the given buffer.
---@param bufnr integer
function progress_bars.clear(bufnr)
  local buffer = Buffer:from_bufnr(bufnr)
  buffer:clear_namespace(ns)
  local timer = timers[bufnr]
  if timer then
    timer:stop()
    timer:close()
    timers[bufnr] = nil
  end
end

function progress_bars.enable(opts)
  options = vim.tbl_extend('force', options, opts)
  progress_bars.enabled = true

  vim.api.nvim_set_hl(0, 'leanProgressBar', { default = true, fg = 'orange', ctermfg = 215 })

  local group = vim.api.nvim_create_augroup('LeanProgressBars', {})

  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = 'lean',
    callback = function(event)
      vim.api.nvim_clear_autocmds { group = group, buffer = event.buf }
      vim.api.nvim_create_autocmd('LspDetach', {
        group = group,
        buffer = event.buf,
        callback = function()
          progress_bars.clear(event.buf)
        end,
      })
    end,
  })
end

return progress_bars
