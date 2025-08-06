local Buffer = require 'std.nvim.buffer'

local goals = {}

---The most recently fetched goals for a position within a buffer.
---@type table<integer, { [1]: integer, [2]: lsp.Position, [3]: InteractiveGoal[] }>
---                        changedtick           position             goals
local cache = {}

---Return the interactive goals at the given position, caching them for access.
---@param params lsp.TextDocumentPositionParams
---@param sess Subsession
---@return InteractiveGoal[]? goals
---@return LspError? err
function goals.at(params, sess)
  local buffer = Buffer:from_uri(params.textDocument.uri)
  if not buffer:is_loaded() then
    return nil, ('%s is not not loaded'):format(buffer.bufnr)
  end

  local tick = buffer.b.changedtick

  local cached = cache[buffer.bufnr]
  local cache_hit = cached and cached[1] == tick and vim.deep_equal(cached[2], params.position)
  if cache_hit then
    return cached[3]
  end

  local result, err = sess:getInteractiveGoals(params)
  if err or not result then
    return nil, err
  end

  cache[buffer.bufnr] = { tick, params.position, result.goals }
  return result.goals, err
end

return goals
