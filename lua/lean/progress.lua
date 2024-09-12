local M = { AUTOCMD = 'LeanProgressUpdate' }

---@alias LeanFileProgressKind 'Processing' | 'FatalError'

---@class LeanFileProgressProcessingInfo
---@field range lsp.Range Range for which the processing info was reported.
---@field kind? LeanFileProgressKind Kind of progress that was reported.

---@type table<lsp.URI, LeanFileProgressProcessingInfo>
M.proc_infos = {}

vim.cmd.hi 'def leanProgressBar guifg=orange ctermfg=215'

function M.update(params)
  M.proc_infos[params.textDocument.uri] = params.processing
  vim.api.nvim_exec_autocmds('User', { pattern = M.AUTOCMD })
end

function M.is_processing(uri)
  return M.proc_infos[uri] and not vim.tbl_isempty(M.proc_infos[uri])
end

function M.is_processing_at(params)
  local this_proc_info = M.proc_infos[params.textDocument.uri]
  if not this_proc_info then
    return true
  end

  -- ignoring character for now (seems to always be 0)
  local line = params.position.line
  return vim.iter(this_proc_info):any(function(each)
    return (line >= each.range.start.line) and (line <= each.range['end'].line)
  end)
end

---Calculate the percentage of a buffer which finished processing.
---@param bufnr? number the buffer number, defaulting to 0
---@return number the percentage of *finished* lines as a number from 0 to 100
function M.percentage(bufnr)
  bufnr = bufnr or 0
  local proc_info = M.proc_infos[vim.uri_from_bufnr(bufnr)]
  if not proc_info then
    return 100
  end

  local finished = vim.iter(proc_info):fold(0, function(acc, range)
    return acc + range.range['end'].line - range.range.start.line
  end)
  return 100 - 100 * finished / vim.api.nvim_buf_line_count(bufnr)
end

return M
