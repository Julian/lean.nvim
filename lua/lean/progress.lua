local M = {}

-- Table from bufnr to current processing info.
M.proc_infos = {}

function M.update(params)
  M.proc_infos[params.textDocument.uri] = params.processing
end

function M.is_processing(uri)
  return M.proc_infos[uri] and not vim.tbl_isempty(M.proc_infos[uri])
end

function M.test_is_processing_at(params)
  local this_proc_info = M.proc_infos[params.textDocument.uri]
  if not this_proc_info then
    return true
  end
  for _, range in pairs(this_proc_info) do
    -- ignoring character for now (seems to always be 0)
    if
      (params.position.line <= range.range['end'].line)
      and (params.position.line >= range.range.start.line)
    then
      return true
    end
  end
  return false
end

function M.is_processing_at(params)
  local this_proc_info = M.proc_infos[params.textDocument.uri]
  -- returning false rather than true for backwards compatibility with
  -- older Lean server versions
  if not this_proc_info then
    return false
  end
  for _, range in pairs(this_proc_info) do
    -- ignoring character for now (seems to always be 0)
    if
      (params.position.line <= range.range['end'].line)
      and (params.position.line >= range.range.start.line)
    then
      return true
    end
  end
  return false
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
