---@mod lean.progress Progress

---@brief [[
--- Indications of Lean's file processing progress.
---@brief ]]

local M = {
  AUTOCMD = 'LeanProgressUpdate',

  ---@enum LeanFileProgressKind
  Kind = {
    processing = 1,
    fatal_error = 2,
  },
}

---@class LeanFileProgressProcessingInfo
---@field range lsp.Range Range for which the processing info was reported.
---@field kind? LeanFileProgressKind Kind of progress that was reported.

---@type table<lsp.URI, LeanFileProgressProcessingInfo[]>
M.proc_infos = {}

vim.cmd.hi 'def leanProgressBar guifg=orange ctermfg=215'

---@param params LeanFileProgressParams
function M.update(params)
  M.proc_infos[params.textDocument.uri] = params.processing
  vim.api.nvim_exec_autocmds('User', { pattern = M.AUTOCMD })
end

---Check if we're processing the given location, returning the kind if so.
---Returns `nil` if we're not processing at the given location.
---@param params lsp.TextDocumentPositionParams
---@return LeanFileProgressKind? kind
function M.at(params)
  local infos = M.proc_infos[params.textDocument.uri]
  if not infos then -- it's so early we don't even have any info yet
    return M.Kind.processing
  end

  -- ignoring character for now (seems to always be 0)
  local line = params.position.line
  ---@type LeanFileProgressProcessingInfo?
  local info = vim.iter(infos):find(function(each)
    return (line >= each.range.start.line) and (line <= each.range['end'].line)
  end)
  return info and (info.kind or M.Kind.processing)
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
