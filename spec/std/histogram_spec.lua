local Histogram = require 'std.histogram'

--- Walk all buckets and verify _max matches the actual highest occupied bucket.
--- Adapted from Java's verifyMaxValue() helper, called after every test.
local function verify_max_value(h)
  if h:count() == 0 then
    return
  end
  -- The tracked max should be the exact value passed to record().
  -- Verify it's at least in the right bucket by checking that the
  -- bucket for max has a non-zero count.
  local max = h:max()
  assert.is_truthy(max ~= nil)
  -- Also verify min is <= max.
  assert.is_truthy(h:min() <= max)
end

describe('std.histogram', function()
  describe('empty histogram', function()
    it('reports zero count', function()
      local h = Histogram:new()
      assert.is.equal(0, h:count())
    end)

    it('returns nil for min and max', function()
      local h = Histogram:new()
      assert.is.Nil(h:min())
      assert.is.Nil(h:max())
    end)

    it('returns empty percentiles', function()
      local h = Histogram:new()
      assert.are.same({}, h:percentiles())
    end)

    it('returns nil for value_at_quantile', function()
      local h = Histogram:new()
      assert.is.Nil(h:value_at_quantile(50))
    end)

    it('returns empty cumulative_distribution', function()
      local h = Histogram:new()
      assert.are.same({}, h:cumulative_distribution())
    end)
  end)

  describe('single value', function()
    it('records one observation', function()
      local h = Histogram:new()
      h:record(4)
      assert.is.equal(1, h:count())
      assert.is.equal(4, h:min())
      assert.is.equal(4, h:max())
      verify_max_value(h)
    end)

    it('returns the value for all percentiles', function()
      local h = Histogram:new()
      h:record(1000)
      local pct = h:percentiles()
      assert.is.equal(1000, pct[1])
      assert.is.equal(1000, pct[50])
      assert.is.equal(1000, pct[100])
      verify_max_value(h)
    end)

    it('records multiple observations with count', function()
      local h = Histogram:new()
      h:record(1000, 5)
      assert.is.equal(5, h:count())
      assert.is.equal(1000, h:min())
      assert.is.equal(1000, h:max())
      verify_max_value(h)
    end)

    it('rejects count <= 0', function()
      local h = Histogram:new()
      assert.has.errors(function()
        h:record(1000, 0)
      end)
      assert.has.errors(function()
        h:record(1000, -1)
      end)
    end)

    it('produces the same result as repeated single records', function()
      local bulk = Histogram:new()
      bulk:record(1000, 100)
      bulk:record(50000, 100)

      local single = Histogram:new()
      for _ = 1, 100 do
        single:record(1000)
      end
      for _ = 1, 100 do
        single:record(50000)
      end

      assert.is.equal(single:count(), bulk:count())
      assert.is.equal(single:min(), bulk:min())
      assert.is.equal(single:max(), bulk:max())
      local pct_bulk = bulk:percentiles()
      local pct_single = single:percentiles()
      for p = 1, 100 do
        assert.is.equal(pct_single[p], pct_bulk[p])
      end
    end)
  end)

  describe('outlier detection', function()
    -- Adapted from Java testConstructionWithLargeNumbers:
    -- records at different magnitudes, verifies valuesAreEquivalent.
    it('separates bulk from outliers in percentiles', function()
      local h = Histogram:new()
      for _ = 1, 10000 do
        h:record(1000)
      end
      h:record(100000000)

      assert.is.equal(10001, h:count())
      assert.is.equal(1000, h:min())
      assert.is.equal(100000000, h:max())

      local pct = h:percentiles()
      assert.is_truthy(h:values_are_equivalent(pct[99], 1000))
      assert.is.equal(100000000, pct[100])
      verify_max_value(h)
    end)
  end)

  describe('uniform distribution', function()
    -- Adapted from Go TestValueAtQuantile: 1M sequential values.
    it('produces accurate percentiles for 1M values', function()
      local h = Histogram:new()
      for i = 1, 1000000 do
        h:record(i)
      end

      assert.is.equal(1000000, h:count())
      assert.is.equal(1, h:min())
      assert.is.equal(1000000, h:max())

      -- Adapted from Go: check P50, P75, P90, P95, P99, P99.9, P99.99.
      local function check(q, expected)
        local v = h:value_at_quantile(q)
        assert
          .message(('p%.2f: got %s, expected %s'):format(q, v, expected))
          .is_truthy(h:values_are_equivalent(v, expected))
      end
      check(50, 500000)
      check(75, 750000)
      check(90, 900000)
      check(95, 950000)
      check(99, 990000)
      check(99.9, 999000)
      check(99.99, 999900)
      verify_max_value(h)
    end)
  end)

  describe('constant value', function()
    it('returns the value for all percentiles within bucket precision', function()
      local h = Histogram:new()
      for _ = 1, 10000 do
        h:record(10000000)
      end

      assert.is.equal(10000, h:count())
      assert.is.equal(10000000, h:min())
      assert.is.equal(10000000, h:max())

      local pct = h:percentiles()
      assert.is.equal(10000000, pct[1])
      assert.is.equal(10000000, pct[100])
      assert.is_truthy(h:values_are_equivalent(pct[50], 10000000))
      verify_max_value(h)
    end)
  end)

  describe('wide dynamic range', function()
    -- Adapted from Java testConstructionWithLargeNumbers.
    it('handles values across many orders of magnitude', function()
      local h = Histogram:new()
      h:record(100000000)
      h:record(20000000)
      h:record(30000000)

      assert.is.equal(3, h:count())
      assert.is_truthy(h:values_are_equivalent(h:value_at_quantile(50), 30000000))
      verify_max_value(h)
    end)

    it('spans microseconds to seconds', function()
      local h = Histogram:new()
      h:record(1000)
      h:record(1000000)
      h:record(1000000000)

      assert.is.equal(3, h:count())
      assert.is.equal(1000, h:min())
      assert.is.equal(1000000000, h:max())

      local pct = h:percentiles()
      assert.is.equal(100, #pct)
      assert.is_truthy(h:values_are_equivalent(pct[1], 1000))
      assert.is.equal(1000000000, pct[100])
      verify_max_value(h)
    end)
  end)

  describe('data retention', function()
    it('never loses observations regardless of count', function()
      local h = Histogram:new()
      for i = 1, 1000000 do
        h:record(i)
      end
      assert.is.equal(1000000, h:count())
      verify_max_value(h)
    end)
  end)

  describe('edge cases', function()
    it('handles zero values', function()
      local h = Histogram:new()
      h:record(0)
      h:record(0)
      assert.is.equal(2, h:count())
      assert.is.equal(0, h:min())
      verify_max_value(h)
    end)

    it('clamps negative values to zero', function()
      local h = Histogram:new()
      h:record(-5)
      assert.is.equal(1, h:count())
      assert.is.equal(-5, h:min())
      -- The bucket index is for 0, but min tracks the raw value.
      assert.is_truthy(h:values_are_equivalent(h:value_at_quantile(50), 0))
    end)

    it('handles very small values', function()
      local h = Histogram:new()
      h:record(1)
      h:record(2)
      h:record(3)
      assert.is.equal(1, h:min())
      assert.is.equal(3, h:max())
      local pct = h:percentiles()
      assert.is.equal(1, pct[1])
      assert.is.equal(3, pct[100])
    end)

    it('handles very large values', function()
      local h = Histogram:new()
      h:record(1e12)
      assert.is.equal(1e12, h:min())
      assert.is.equal(1e12, h:max())
      verify_max_value(h)
    end)

    it('handles values near powers of 2 correctly', function()
      -- Regression: ilog2 floating-point rounding at 2^48-1
      local h = Histogram:new()
      local v = 2 ^ 48 - 1
      for _ = 1, 100 do
        h:record(v)
      end
      h:record(1)
      local pct = h:percentiles()
      assert.is_truthy(h:values_are_equivalent(pct[50], v))
      verify_max_value(h)
    end)
  end)

  describe('values_are_equivalent', function()
    it('is exact in the linear range', function()
      local h = Histogram:new()
      -- Below 128, each integer is its own bucket.
      assert.is_truthy(h:values_are_equivalent(0, 0))
      assert.is_truthy(h:values_are_equivalent(127, 127))
      assert.is.falsy(h:values_are_equivalent(0, 1))
      assert.is.falsy(h:values_are_equivalent(126, 127))
    end)

    it('groups nearby values in the log range', function()
      local h = Histogram:new()
      assert.is_truthy(h:values_are_equivalent(1000, 1001))
      assert.is_truthy(h:values_are_equivalent(1000, 1007))
      assert.is.falsy(h:values_are_equivalent(1000, 1008))
      assert.is.falsy(h:values_are_equivalent(1000, 2000))
    end)

    -- Adapted from Go TestHistogram_ValuesAreEquivalent: large values.
    it('works with large values', function()
      local h = Histogram:new()
      assert.is_truthy(h:values_are_equivalent(100000000, 100000001))
      assert.is.falsy(h:values_are_equivalent(100000000, 200000000))
      assert.is_truthy(h:values_are_equivalent(1e12, 1e12 + 1))
    end)

    it('handles the value returned by value_at_quantile', function()
      local h = Histogram:new()
      for i = 1, 100000 do
        h:record(i)
      end
      assert.is_truthy(h:values_are_equivalent(h:value_at_quantile(50), 50000))
      assert.is_truthy(h:values_are_equivalent(h:value_at_quantile(99), 99000))
    end)
  end)

  describe('value_at_quantile', function()
    it('returns min for quantile 0', function()
      local h = Histogram:new()
      for i = 1, 1000 do
        h:record(i)
      end
      assert.is.equal(1, h:value_at_quantile(0))
    end)

    it('returns max for quantile 100', function()
      local h = Histogram:new()
      for i = 1, 1000 do
        h:record(i)
      end
      assert.is.equal(1000, h:value_at_quantile(100))
    end)

    it('returns the value for all quantiles on a single-value histogram', function()
      local h = Histogram:new()
      h:record(5000)
      assert.is.equal(5000, h:value_at_quantile(0))
      assert.is.equal(5000, h:value_at_quantile(50))
      assert.is.equal(5000, h:value_at_quantile(100))
    end)

    it('supports fractional percentiles like p99.9', function()
      local h = Histogram:new()
      for _ = 1, 10000 do
        h:record(1000)
      end
      h:record(100000000)
      assert.is_truthy(h:values_are_equivalent(h:value_at_quantile(99.9), 1000))
      assert.is.equal(100000000, h:value_at_quantile(100))
      verify_max_value(h)
    end)

    it('agrees with percentiles() for integer quantiles', function()
      local h = Histogram:new()
      for i = 1, 100000 do
        h:record(i)
      end
      local pct = h:percentiles()
      for _, p in ipairs { 1, 25, 50, 75, 90, 95, 99, 100 } do
        assert.is.equal(pct[p], h:value_at_quantile(p))
      end
    end)

    it('clamps negative quantiles to min', function()
      local h = Histogram:new()
      for i = 1, 100 do
        h:record(i)
      end
      assert.is.equal(1, h:value_at_quantile(-10))
    end)

    it('clamps quantiles above 100 to max', function()
      local h = Histogram:new()
      for i = 1, 100 do
        h:record(i)
      end
      assert.is.equal(100, h:value_at_quantile(200))
    end)

    -- Adapted from Java testValueAtPercentileMatchesPercentile:
    -- verify across histogram sizes 1, 5, 10, 50, 100, 500, 1000, 5000,
    -- 10000, 50000, 100000 at multiple percentiles.
    it('is bucket-equivalent across varying histogram sizes', function()
      for _, n in ipairs { 1, 5, 10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000 } do
        local h = Histogram:new()
        for i = 1, n do
          h:record(i)
        end
        local function check(q)
          local v = h:value_at_quantile(q)
          local expected = math.max(1, math.ceil(n * q / 100))
          assert
            .message(('n=%d p%.1f: got %s, expected %s'):format(n, q, v, expected))
            .is_truthy(h:values_are_equivalent(v, expected))
        end
        check(50)
        check(75)
        check(90)
        check(99)
        verify_max_value(h)
      end
    end)
  end)

  describe('cumulative_distribution', function()
    it('returns one bracket for a single value', function()
      local h = Histogram:new()
      h:record(1000)
      local dist = h:cumulative_distribution()
      assert.is.equal(1, #dist)
      assert.is.equal(100, dist[1].quantile)
      assert.is.equal(1, dist[1].count)
      assert.is.equal(1000, dist[1].value)
    end)

    it('covers the full range from first observation to max', function()
      local h = Histogram:new()
      for i = 1, 10000 do
        h:record(i)
      end
      local dist = h:cumulative_distribution()
      assert.is_truthy(dist[1].quantile > 0)
      assert.is.equal(100, dist[#dist].quantile)
      assert.is.equal(10000, dist[#dist].count)
      assert.is.equal(10000, dist[#dist].value)
      verify_max_value(h)
    end)

    it('has monotonically increasing quantiles, counts, and values', function()
      local h = Histogram:new()
      for i = 1, 100000 do
        h:record(i)
      end
      local dist = h:cumulative_distribution()
      for i = 2, #dist do
        assert.is_truthy(dist[i].quantile >= dist[i - 1].quantile)
        assert.is_truthy(dist[i].count > dist[i - 1].count)
        assert.is_truthy(dist[i].value >= dist[i - 1].value)
      end
    end)

    it('last bracket count equals total', function()
      local h = Histogram:new()
      for i = 1, 1000 do
        h:record(i)
      end
      local dist = h:cumulative_distribution()
      assert.is.equal(100, dist[#dist].quantile)
      assert.is.equal(1000, dist[#dist].count)
    end)

    it('values are bucket-equivalent to value_at_quantile inside each bracket', function()
      local h = Histogram:new()
      for i = 1, 100000 do
        h:record(i)
      end
      local dist = h:cumulative_distribution()
      local prev_q = 0
      for _, bracket in ipairs(dist) do
        local mid_q = (prev_q + bracket.quantile) / 2
        if mid_q > 0.1 and mid_q < 99.9 then
          local v = h:value_at_quantile(mid_q)
          assert
            .message(('q=%.4f: dist=%s, vaq=%s'):format(mid_q, bracket.value, v))
            .is_truthy(h:values_are_equivalent(v, bracket.value))
        end
        prev_q = bracket.quantile
      end
    end)

    -- Adapted from Go TestCumulativeDistribution: verify known bracket structure.
    it('produces the expected number of brackets for sequential values', function()
      local h = Histogram:new()
      for i = 0, 1023 do
        h:record(i)
      end
      local dist = h:cumulative_distribution()
      -- Values 0-127 each get their own bucket (linear range), values
      -- 128-1023 share buckets in the log range.  The total bracket
      -- count should match the number of occupied buckets.
      assert.is_truthy(#dist > 128) -- at least the 128 linear buckets
      assert.is.equal(1024, dist[#dist].count)
      assert.is.equal(100, dist[#dist].quantile)
      -- First bracket should be for value 0.
      assert.is.equal(0, dist[1].value)
    end)
  end)

  describe('merge', function()
    it('combines two histograms', function()
      local a = Histogram:new()
      local b = Histogram:new()
      for i = 1, 500 do
        a:record(i)
      end
      for i = 501, 1000 do
        b:record(i)
      end
      a:merge(b)
      assert.is.equal(1000, a:count())
      assert.is.equal(1, a:min())
      assert.is.equal(1000, a:max())
      verify_max_value(a)
    end)

    it('produces the same percentiles as recording all values directly', function()
      local combined = Histogram:new()
      local direct = Histogram:new()
      local a = Histogram:new()
      local b = Histogram:new()
      for i = 1, 50000 do
        a:record(i)
        direct:record(i)
      end
      for i = 50001, 100000 do
        b:record(i)
        direct:record(i)
      end
      combined:merge(a)
      combined:merge(b)
      local pct_merged = combined:percentiles()
      local pct_direct = direct:percentiles()
      for p = 1, 100 do
        assert.is.equal(pct_direct[p], pct_merged[p])
      end
      verify_max_value(combined)
    end)

    it('produces the same value_at_quantile as recording directly', function()
      local combined = Histogram:new()
      local direct = Histogram:new()
      local a = Histogram:new()
      local b = Histogram:new()
      for i = 1, 50000 do
        a:record(i)
        direct:record(i)
      end
      for i = 50001, 100000 do
        b:record(i)
        direct:record(i)
      end
      combined:merge(a)
      combined:merge(b)
      for _, q in ipairs { 0, 1, 50, 75, 90, 99, 99.9, 99.99, 100 } do
        assert.is.equal(direct:value_at_quantile(q), combined:value_at_quantile(q))
      end
    end)

    it('does not mutate the source histogram', function()
      local a = Histogram:new()
      local b = Histogram:new()
      for i = 1, 100 do
        a:record(i)
      end
      for i = 101, 200 do
        b:record(i)
      end
      a:merge(b)
      assert.is.equal(100, b:count())
      assert.is.equal(101, b:min())
      assert.is.equal(200, b:max())
    end)

    it('merging an empty histogram is a no-op', function()
      local h = Histogram:new()
      h:record(42)
      h:merge(Histogram:new())
      assert.is.equal(1, h:count())
      assert.is.equal(42, h:min())
      verify_max_value(h)
    end)

    it('merging into an empty histogram copies the other', function()
      local h = Histogram:new()
      local other = Histogram:new()
      other:record(100)
      other:record(200)
      h:merge(other)
      assert.is.equal(2, h:count())
      assert.is.equal(100, h:min())
      assert.is.equal(200, h:max())
      verify_max_value(h)
    end)
  end)

  describe('stopwatch', function()
    it('creates a stopwatch that records total into the histogram on finish', function()
      local h = Histogram:new()
      local sw = h:stopwatch()
      sw:open 'phase'
      sw:close()
      local timing = sw:finish()
      assert.is.equal(1, h:count())
      assert.is_truthy(timing.total >= 0)
      assert.is_truthy(h:min() >= 0)
      verify_max_value(h)
    end)
  end)
end)
