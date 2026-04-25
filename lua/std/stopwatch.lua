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
---@field private _result table<string, integer>
---@field private _stack string[]
---@field private _starts integer[]
---@field private _birth integer
local Stopwatch = {}
Stopwatch.__index = Stopwatch

---Create a new stopwatch. The clock starts immediately.
---
---An optional `clock` function may be provided for testing;
---it defaults to `vim.uv.hrtime`.
---@param clock? fun(): integer a function returning monotonic nanoseconds
---@return std.Stopwatch
function Stopwatch:new(clock)
  clock = clock or vim.uv.hrtime
  return setmetatable({
    _clock = clock,
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
---from creation to finish.
---@return table<string, integer>
function Stopwatch:finish()
  self._result.total = self._clock() - self._birth
  return self._result
end

return Stopwatch
