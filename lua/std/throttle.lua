---@mod std.throttle Throttle
---@brief [[
--- Leading-edge throttle with trailing flush.
---@brief ]]

--- Create a throttled function that fires immediately on the first call,
--- then suppresses further calls during an `ms` millisecond cooldown.
--- If calls were suppressed, the latest one fires after the cooldown expires.
---@param ms integer cooldown in milliseconds
---@param fn function the function to throttle
---@return function throttled the throttled wrapper
local function throttle(ms, fn)
  if ms == 0 then
    return fn
  end

  local timer = vim.uv.new_timer()
  local pending = nil

  return function(...)
    if not timer:is_active() then
      fn(...)
    else
      pending = { ... }
    end
    timer:start(
      ms,
      0,
      vim.schedule_wrap(function()
        if pending then
          local args = pending
          pending = nil
          fn(unpack(args))
        end
      end)
    )
  end
end

return throttle
