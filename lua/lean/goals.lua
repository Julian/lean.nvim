local Buffer = require 'std.nvim.buffer'

local goals = {}

---@class GoalsCacheEntry
---@field session Session the RPC session whose refs the goals embed
---@field tick integer the buffer's changedtick when the goals were fetched
---@field position lsp.Position
---@field goals InteractiveGoal[]

---The most recently fetched goals for a position within a buffer.
---
---Cache entries are invalidated on a session change because the embedded
---RPC references are scoped to the session that issued them; sending them
---back through a different session yields "RPC reference is not valid".
---@type table<integer, GoalsCacheEntry>
local cache = {}

---Return the interactive goals at the given position, caching them for access.
---@param sess ReconnectingSubsession
---@return InteractiveGoal[]? goals
---@return LspError? err
function goals.at(sess)
  local params = sess.pos
  local buffer = Buffer:from_uri(params.textDocument.uri)
  if not buffer:is_loaded() then
    return nil, ('%s is not not loaded'):format(buffer.bufnr)
  end

  local tick = buffer.b.changedtick
  local current_session = sess.sess

  local cached = cache[buffer.bufnr]
  local cache_hit = cached
    and cached.session == current_session
    and cached.tick == tick
    and vim.deep_equal(cached.position, params.position)
  if cache_hit then
    return cached.goals
  end

  local result, err = sess:getInteractiveGoals()
  if err or not result then
    return nil, err
  end

  -- Re-read `sess.sess` after the call: `ReconnectingSubsession:call`
  -- may have swapped to a new session on retry, in which case the refs
  -- in `result` are from the new one, not from `current_session`.
  cache[buffer.bufnr] = {
    session = sess.sess,
    tick = tick,
    position = params.position,
    goals = result.goals,
  }
  return result.goals, err
end

return goals
