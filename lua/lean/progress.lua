local M = {}

-- Table from bufnr to current processing info.
M.proc_infos = {}

function M.update(params)
  M.proc_infos[params.textDocument.uri] = params.processing
end

function M.is_processing(uri)
    return M.proc_infos[uri] and not vim.tbl_isempty(M.proc_infos[uri])
  end

function M.is_processing_at(params)
  local this_proc_info = M.proc_infos[params.textDocument.uri]
  -- returning false rather than true for backwards compatibility with
  -- older Lean 3/4 server versions
  if not this_proc_info then return false end
  for _, range in pairs(this_proc_info) do
    -- ignoring character for now (seems to always be 0)
    if (params.position.line <= range.range["end"].line) and (params.position.line >= range.range.start.line) then
      return true
    end
  end
  return false
end

return M
