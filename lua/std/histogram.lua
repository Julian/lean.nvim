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
---@param count? integer number of observations (default 1, must be > 0)
function Histogram:record(value, count)
  count = count or 1
  assert(count > 0, 'count must be positive')
  local idx = bucket_for(math.floor(math.max(0, value)))
  self._counts[idx] = (self._counts[idx] or 0) + count
  self._total = self._total + count
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

---Return whether two values are equivalent (map to the same bucket).
---
---This is the correct way to compare histogram output: two values are
---"the same" if the histogram can't distinguish them.
---@param a number
---@param b number
---@return boolean
function Histogram:values_are_equivalent(a, b) -- luacheck: no unused args
  return bucket_for(math.floor(math.max(0, a))) == bucket_for(math.floor(math.max(0, b)))
end

---Return the value at a given quantile.
---
---Quantile is 0–100 with arbitrary decimal precision (e.g. 99.9, 99.99).
---Returns the bucket midpoint for the bucket containing that quantile's
---observation (contrast with Java HdrHistogram which returns the highest
---equivalent value; midpoint gives ~0.4% average error vs ~0.8% worst-case).
---Edge cases: p0 returns exact min, p100 returns exact max.
---Returns nil if the histogram is empty.
---@param quantile number 0–100
---@return number?
function Histogram:value_at_quantile(quantile)
  if self._total == 0 then
    return
  end
  if self._min == self._max then
    return self._min
  end
  if quantile <= 0 then
    return self._min
  end
  if quantile >= 100 then
    return self._max
  end
  local target = math.ceil(self._total * quantile / 100)
  local cumulative = 0
  for idx = 0, BUCKET_COUNT - 1 do
    local c = self._counts[idx]
    if c then
      cumulative = cumulative + c
      if cumulative >= target then
        return value_for(idx)
      end
    end
  end
  return self._max
end

---Compute percentiles (1 through 100).
---
---Returns an array where result[p] is the value at the p-th percentile.
---For single or fractional percentile queries, use value_at_quantile.
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

---Return the cumulative distribution as an array of brackets.
---
---Iterates over actual bucket boundaries rather than sampling at fixed
---percentile intervals, giving the exact shape of the recorded distribution.
---Each bracket has quantile (0–100), count (cumulative observation count),
---and value (bucket representative).
---Matches Go's CumulativeDistribution().
---@return {quantile: number, count: integer, value: number}[]
function Histogram:cumulative_distribution()
  if self._total == 0 then
    return {}
  end
  local result = {}
  local cumulative = 0
  for idx = 0, BUCKET_COUNT - 1 do
    local c = self._counts[idx]
    if c then
      cumulative = cumulative + c
      result[#result + 1] = {
        quantile = cumulative / self._total * 100,
        count = cumulative,
        value = value_for(idx),
      }
    end
  end
  -- Clamp the final entry to exact max.
  if #result > 0 then
    result[#result].value = self._max
  end
  return result
end

---Merge another histogram into this one.
---
---Adds all observations from other without losing precision.
---The two histograms must use the same bucket scheme (same PRECISION).
---@param other std.Histogram
function Histogram:merge(other)
  for idx, c in pairs(other._counts) do
    self._counts[idx] = (self._counts[idx] or 0) + c
  end
  self._total = self._total + other._total
  if other._total > 0 then
    if other._min < self._min then
      self._min = other._min
    end
    if other._max > self._max then
      self._max = other._max
    end
  end
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
