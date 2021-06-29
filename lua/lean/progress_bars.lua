local M = {}
local options = {}

local progress_sign = 'leanSignProgress'
local sign_ns = 'leanSignProgress'

-- Table from bufnr to current processing info.
local proc_infos = {}

local function update(bufnr)
  vim.fn.sign_unplace(sign_ns, {buffer=bufnr})
  for _, proc_info in ipairs(proc_infos[bufnr]) do
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

local function on_file_progress(err, _, params, _, _, _)
  if err ~= nil then return end
  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  proc_infos[bufnr] = params.processing
  if timers[bufnr] == nil then
    timers[bufnr] = vim.defer_fn(function ()
      timers[bufnr] = nil
      update(bufnr)
    end, 100)
  end
end

function M.enable(opts)
  options.priority = opts.priority or 10
  vim.fn.sign_define(progress_sign, {
    text = '#',
    texthl = 'leanSignProgress',
  })
  vim.cmd([[ hi def leanSignProgress guifg=orange ctermfg=215 ]])
  vim.lsp.handlers['$/lean/fileProgress'] = on_file_progress
end

return M
