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

---Like `at`, but also returns processing if the file has processing
---ranges that haven't reached the given position yet.
---This is needed when e.g. imports are building and the cursor is on a
---later line that hasn't been reached yet.
---@param params lsp.TextDocumentPositionParams
---@return LeanFileProgressKind? kind
function M.at_or_file(params)
  local infos = M.proc_infos[params.textDocument.uri]
  if not infos then
    return M.Kind.processing
  end
  if #infos == 0 then
    return
  end

  local line = params.position.line
  ---@type LeanFileProgressProcessingInfo?
  local info = vim.iter(infos):find(function(each)
    return (line >= each.range.start.line) and (line <= each.range['end'].line)
  end)
  if info then
    return info.kind or M.Kind.processing
  end

  -- Cursor is not in any processing range. If processing hasn't reached
  -- the cursor yet (cursor is past all ranges), treat as processing.
  -- Lean processes top-to-bottom, so this means the cursor's line is
  -- waiting for earlier lines (e.g. imports) to finish.
  local max_end = vim.iter(infos):fold(-1, function(acc, each)
    return math.max(acc, each.range['end'].line)
  end)
  if line > max_end then
    return M.Kind.processing
  end
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
