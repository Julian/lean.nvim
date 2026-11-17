---@mod std.debounce Debounce
---@brief [[
--- Leading-edge debounce with trailing flush.
---@brief ]]

--- Create a debounced function that fires immediately on the first call,
--- then suppresses further calls until `ms` milliseconds have elapsed since
--- the most recent call. If calls were suppressed, the latest one fires once
--- the quiet period expires.
---@param ms integer quiet period in milliseconds
---@param fn function the function to debounce
---@return function debounced the debounced wrapper
---@return fun(): boolean is_pending whether a suppressed call is waiting to flush
local function debounce(ms, fn)
  if ms == 0 then
    return fn, function()
      return false
    end
  end

  local timer = vim.uv.new_timer()
  local pending = nil

  local function debounced(...)
    if not timer:is_active() and not pending then
      fn(...)
    else
      pending = { ... }
    end
    timer:start(
      ms,
      0,
      vim.schedule_wrap(function()
        if pending and not timer:is_active() then
          local args = pending
          pending = nil
          fn(unpack(args))
        end
      end)
    )
  end

  return debounced, function()
    return pending ~= nil
  end
end

return debounce
