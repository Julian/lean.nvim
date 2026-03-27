---@mod std.async Async
---@brief [[
--- Minimal async primitives built on Lua coroutines.
---@brief ]]

local async = {}

---@class std.async.Event
---@field set fun() Signal all waiting coroutines to resume.
---@field wait fun() Yield until the event is set. Returns immediately if already set.

---Report a coroutine error on the next event loop tick.
---@param co thread
---@param err string
local function rethrow(co, err)
  vim.schedule(function()
    error(debug.traceback(co, err))
  end)
end

--- Run an async function in a new coroutine.
---@param fn fun() the async function to run
function async.run(fn)
  local co = coroutine.create(fn)
  local ok, err = coroutine.resume(co)
  if not ok then
    rethrow(co, err)
  end
end

--- Wrap a callback-style function for use inside an async context.
---
--- The original function must accept a callback as its last (argc-th)
--- argument. The returned function, when called inside a coroutine,
--- yields until that callback fires and then returns its results.
---@param fn function a callback-style function
---@param argc integer the total number of arguments (including the callback)
---@return function wrapped an async version of fn
function async.wrap(fn, argc)
  return function(...)
    local co = coroutine.running()
    assert(co, 'async.wrap: must be called from a coroutine')
    local args = { ... }
    args[argc] = function(...)
      local ok, err = coroutine.resume(co, ...)
      if not ok then
        rethrow(co, err)
      end
    end
    fn(unpack(args, 1, argc))
    return coroutine.yield()
  end
end

--- Create an event that async code can wait on.
---
--- Multiple coroutines can wait on the same event.
--- Once set, all current and future waiters resume immediately.
---@return std.async.Event
function async.event()
  local is_set = false
  local waiters = {}
  return {
    set = function()
      is_set = true
      for _, co in ipairs(waiters) do
        local ok, err = coroutine.resume(co)
        if not ok then
          rethrow(co, err)
        end
      end
      waiters = {}
    end,
    wait = function()
      if is_set then return end
      local co = coroutine.running()
      assert(co, 'event.wait: must be called from a coroutine')
      table.insert(waiters, co)
      coroutine.yield()
    end,
  }
end

return async
