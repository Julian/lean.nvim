local Stopwatch = require 'std.stopwatch'

---A simple HDR histogram for recording distributions without data loss.
---
---Uses a log-linear bucket scheme inspired by the Wingolog approach:
---values below 2^PRECISION are bucketed linearly (exact), values above
---are bucketed with PRECISION bits of mantissa (relative error ~1/2^PRECISION).
---
---Fixed memory, O(1) recording, O(bucket_count) percentile queries.
---Every observation is counted — no data eviction.
---
---    local h = Histogram:new()
---    h:record(1500000)   -- 1.5ms in nanoseconds
---    h:record(20000000)  -- 20ms
---    local pct = h:percentiles()
---    -- pct[50], pct[99], etc.
---
---@class std.Histogram
---@field private _counts integer[]
---@field private _total integer
---@field private _min number
---@field private _max number
local Histogram = {}
Histogram.__index = Histogram

-- 7 bits of precision → ~0.8% relative error, 128 sub-buckets per doubling.
-- Lua numbers are doubles with 53 bits of integer precision, so we cover
-- values from 0 to 2^53 with (53 - 7 + 1) * 128 = 6016 buckets.
local PRECISION = 7
local LINEAR_COUNT = 2 ^ PRECISION -- 128: values [0, 128) are exact
local MAX_BITS = 53
local BUCKET_COUNT = (MAX_BITS - PRECISION + 1) * LINEAR_COUNT

---Floor of log2 for positive integers (highest set bit position).
---@param value number
---@return integer
local function ilog2(value)
  local _, exp = math.frexp(value)
  return exp - 1
end

---Map a value to a bucket index.
---@param value integer
---@return integer 0-based bucket index
local function bucket_for(value)
  if value < LINEAR_COUNT then
    return value
  end
  local mag = ilog2(value)
  local shift = mag - PRECISION + 1
  local mantissa = math.floor(value / (2 ^ shift))
  local prefix = mantissa % LINEAR_COUNT
  local idx = shift * LINEAR_COUNT + prefix
  if idx >= BUCKET_COUNT then
    idx = BUCKET_COUNT - 1
  end
  return idx
end

---Map a bucket index back to a representative value (bucket midpoint).
---@param idx integer 0-based bucket index
---@return number
local function value_for(idx)
  if idx < LINEAR_COUNT then
    return idx
  end
  local shift = math.floor(idx / LINEAR_COUNT)
  local minor = idx % LINEAR_COUNT
  local lo = minor * (2 ^ shift)
  local bucket_size = 2 ^ shift
  return lo + bucket_size / 2
end

---Create a new empty histogram.
---@return std.Histogram
function Histogram:new()
  return setmetatable({
    _counts = {},
    _total = 0,
    _min = math.huge,
    _max = -math.huge,
  }, self)
end

---Record a value.
---@param value number
function Histogram:record(value)
  local idx = bucket_for(math.floor(math.max(0, value)))
  self._counts[idx] = (self._counts[idx] or 0) + 1
  self._total = self._total + 1
  if value < self._min then
    self._min = value
  end
  if value > self._max then
    self._max = value
  end
end

---Return the total number of observations.
---@return integer
function Histogram:count()
  return self._total
end

---Return the minimum recorded value (or nil if empty).
---@return number?
function Histogram:min()
  if self._total == 0 then
    return
  end
  return self._min
end

---Return the maximum recorded value (or nil if empty).
---@return number?
function Histogram:max()
  if self._total == 0 then
    return
  end
  return self._max
end

---Compute percentiles (1 through 100).
---
---Returns an array where result[p] is the value at the p-th percentile.
---@return number[]
function Histogram:percentiles()
  if self._total == 0 then
    return {}
  end
  local result = {}
  local cumulative = 0
  local next_pct = 1
  local target = math.ceil(self._total * next_pct / 100)

  for idx = 0, BUCKET_COUNT - 1 do
    local c = self._counts[idx]
    if c then
      cumulative = cumulative + c
      while next_pct <= 100 and cumulative >= target do
        result[next_pct] = value_for(idx)
        next_pct = next_pct + 1
        target = math.ceil(self._total * next_pct / 100)
      end
    end
    if next_pct > 100 then
      break
    end
  end

  -- Clamp p100 to exact max (bucket midpoint may undershoot).
  result[100] = self._max

  -- When all observations are the same value, all percentiles are exact.
  if self._min == self._max then
    for p = 1, 100 do
      result[p] = self._min
    end
  end

  return result
end

---Create a Stopwatch that records its total duration into this histogram
---when finished.
---@param clock? fun(): integer optional clock (passed to Stopwatch:new)
---@return std.Stopwatch
function Histogram:stopwatch(clock)
  local histogram = self
  return Stopwatch:new(clock, function(result)
    histogram:record(result.total)
  end)
end

return Histogram
