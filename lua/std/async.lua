---@mod std.async Async
---@brief [[
--- Minimal async primitives built on Lua coroutines.
---@brief ]]

local async = {}

---@class std.async.Event
---@field set fun() Signal all waiting coroutines to resume.
---@field wait fun() Yield until the event is set. Returns immediately if already set.

---Captured errors from coroutines, when inside a `capture_errors` block.
---@type string[]?
local captured_errors

---Report a coroutine error on the next event loop tick.
---@param co thread
---@param err string
local function rethrow(co, err)
  local traceback = debug.traceback(co, err)
  if captured_errors then
    table.insert(captured_errors, traceback)
    return
  end
  vim.schedule(function()
    error(traceback)
  end)
end

--- Run a function while capturing any async coroutine errors.
---
--- Errors from coroutines that crash during `fn` are captured instead
--- of being rethrown via `vim.schedule`. The captured error tracebacks
--- are returned.
---
--- Errors if `fn` produces no async errors (since the intent of
--- calling this is to assert that errors *do* occur).
---@param fn fun()
---@return string[] errors
function async.capture_errors(fn)
  local previous = captured_errors
  captured_errors = {}
  local errors = captured_errors
  local ok, err = pcall(fn)
  captured_errors = previous
  if not ok then
    error(err, 2)
  end
  if #errors == 0 then
    error('async.capture_errors: expected coroutine errors but none occurred', 2)
  end
  return errors
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

--- Run multiple async functions concurrently and wait for all to finish.
---
--- Each function runs in its own coroutine. The caller yields until all
--- functions have completed, then resumes with a list of result tables
--- (one per function, holding that function's return values).
---
--- If any function errors, the first error is re-raised in the caller
--- after all the others have finished. This is closer to `asyncio.gather`
--- than to a Trio nursery — there's no cancellation, so siblings of an
--- erroring child still run to completion before the error surfaces.
---@param fns (fun(): ...)[]
---@return any[][] results one entry per fn, holding its return values
function async.join(fns)
  local n = #fns
  local results = {}
  if n == 0 then
    return results
  end

  local co = coroutine.running()
  assert(co, 'async.join: must be called from a coroutine')

  local remaining = n
  local first_err = nil
  for i, fn in ipairs(fns) do
    async.run(function()
      local ok, ret = xpcall(function()
        return { fn() }
      end, debug.traceback)
      if ok then
        results[i] = ret
      else
        results[i] = {}
        first_err = first_err or ret
      end
      remaining = remaining - 1
      if remaining == 0 and coroutine.status(co) == 'suspended' then
        local rok, rerr = coroutine.resume(co)
        if not rok then
          rethrow(co, rerr)
        end
      end
    end)
  end

  if remaining > 0 then
    coroutine.yield()
  end
  if first_err then
    error(first_err, 0)
  end
  return results
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
      if is_set then
        return
      end
      local co = coroutine.running()
      assert(co, 'event.wait: must be called from a coroutine')
      table.insert(waiters, co)
      coroutine.yield()
    end,
  }
end

return async
