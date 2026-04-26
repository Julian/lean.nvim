---A hierarchical stopwatch for timing sequential and nested operations.
---
---Call :open(name) / :close() to bracket phases.  Phases can nest:
---opening a phase inside another records it as a child.
---:finish() returns a flat table of durations keyed by dotted paths.
---
---    local sw = Stopwatch:new()
---    sw:open 'content'
---      sw:open 'goals'
---      sw:close()
---    sw:close()
---    sw:open 'render'
---    sw:close()
---    local t = sw:finish()
---    -- { total = 579, content = 123, ['content.goals'] = 45, render = 456 }
---
---@class std.Stopwatch
---@field private _clock fun(): integer
---@field private _on_finish fun(result: table<string, integer>)
---@field private _result table<string, integer>
---@field private _stack string[]
---@field private _starts integer[]
---@field private _birth integer
local Stopwatch = {}
Stopwatch.__index = Stopwatch

---Create a new stopwatch. The clock starts immediately.
---
---An optional `clock` function may be provided for testing;
---it defaults to `vim.uv.hrtime`.  An optional `on_finish`
---callback is called with the result table when :finish() is called.
---@param clock? fun(): integer a function returning monotonic nanoseconds
---@param on_finish? fun(result: table<string, integer>) called on finish
---@return std.Stopwatch
function Stopwatch:new(clock, on_finish)
  clock = clock or vim.uv.hrtime
  return setmetatable({
    _clock = clock,
    _on_finish = on_finish or function() end,
    _result = {},
    _stack = {},
    _starts = {},
    _birth = clock(),
  }, self)
end

---Open a named phase. Nesting is allowed.
---@param name string
function Stopwatch:open(name)
  self._stack[#self._stack + 1] = name
  self._starts[#self._starts + 1] = self._clock()
end

---Close the current phase, recording its duration.
function Stopwatch:close()
  local elapsed = self._clock() - table.remove(self._starts)
  local key = table.concat(self._stack, '.')
  table.remove(self._stack)
  self._result[key] = elapsed
end

---Run named async functions concurrently, recording each individually as a
---sibling phase under the currently-open phase, plus a wall-clock duration
---of the parallel section under `wall_name`.
---
---Each function runs in its own coroutine via `std.async.join`, so the
---caller must itself be inside a coroutine. The open/close stack is not
---used for the children (it would interleave under concurrency); each
---child's key is computed as `<current path>.<child name>`, alongside
---`<current path>.<wall_name>`.
---
---@param wall_name string  phase name under which to record wall-clock time
---@param phases { [1]: string, [2]: fun(): ... }[]  ordered (name, fn) pairs
---@return any[][] results  one result tuple per phase, in input order
function Stopwatch:concurrent(wall_name, phases)
  local async = require 'std.async'

  local prefix = #self._stack > 0 and table.concat(self._stack, '.') .. '.' or ''

  local fns = {}
  for i, phase in ipairs(phases) do
    local child_name, child_fn = phase[1], phase[2]
    fns[i] = function()
      local start = self._clock()
      local result = { child_fn() }
      self._result[prefix .. child_name] = self._clock() - start
      return unpack(result)
    end
  end

  local outer_start = self._clock()
  local results = async.join(fns)
  self._result[prefix .. wall_name] = self._clock() - outer_start

  return results
end

---Time a function call as a named phase.
---Opens the phase, calls fn, closes the phase, and returns fn's results.
---@param name string
---@param fn fun(...): ...
---@return ...
function Stopwatch:time(name, fn, ...)
  self:open(name)
  local results = { fn(...) }
  self:close()
  return unpack(results)
end

---Finish timing and return all phase durations.
---
---Returns a flat table mapping dotted phase paths to durations
---in nanoseconds.  Also includes a 'total' key for the wall time
---from creation to finish.  Calls on_finish if one was provided.
---@return table<string, integer>
function Stopwatch:finish()
  self._result.total = self._clock() - self._birth
  self._on_finish(self._result)
  return self._result
end

return Stopwatch
