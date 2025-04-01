local goals = {}

---Return the interactive goals at the given position, caching them for access.
---@param params lsp.TextDocumentPositionParams
---@param sess Subsession
---@return InteractiveGoal[]? goals
---@return LspError? err
function goals.update_at(params, sess)
  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return nil, ('%s is not not loaded'):format(bufnr)
  end

  local result, err = sess:getInteractiveGoals(params)
  if err then
    return nil, err
  end

  return result and result.goals, err
end

return goals
