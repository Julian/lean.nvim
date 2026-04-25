local Histogram = require 'std.histogram'

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
  end)

  describe('single value', function()
    it('records one observation', function()
      local h = Histogram:new()
      h:record(4)
      assert.is.equal(1, h:count())
      assert.is.equal(4, h:min())
      assert.is.equal(4, h:max())
    end)

    it('returns the value for all percentiles', function()
      local h = Histogram:new()
      h:record(1000)
      local pct = h:percentiles()
      assert.is.equal(1000, pct[1])
      assert.is.equal(1000, pct[50])
      assert.is.equal(1000, pct[100])
    end)
  end)

  describe('outlier detection', function()
    -- Adapted from Java/C canonical test:
    -- 10000 observations at 1000, then 1 observation at 100000000.
    -- p99 should still be near 1000, p99.999 ≈ 100000000.
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
      -- p99 should be near 1000 (the bulk)
      assert.is_truthy(math.abs(pct[99] - 1000) / 1000 < 0.02)
      -- p100 is the outlier
      assert.is.equal(100000000, pct[100])
    end)
  end)

  describe('uniform distribution', function()
    -- Adapted from Go test: record every integer from 1 to 100000.
    it('produces accurate percentiles', function()
      local h = Histogram:new()
      for i = 1, 100000 do
        h:record(i)
      end

      assert.is.equal(100000, h:count())
      assert.is.equal(1, h:min())
      assert.is.equal(100000, h:max())

      local pct = h:percentiles()
      -- All percentiles should be within ~1% of the expected value.
      local function check(p, expected)
        local err = math.abs(pct[p] - expected) / expected
        assert
          .message(('p%d: got %s, expected %s, error %.2f%%'):format(p, pct[p], expected, err * 100))
          .is_truthy(err < 0.02)
      end
      check(50, 50000)
      check(75, 75000)
      check(90, 90000)
      check(99, 99000)
    end)
  end)

  describe('constant value', function()
    it('returns the value for all percentiles within bucket precision', function()
      local h = Histogram:new()
      for _ = 1, 10000 do
        h:record(10000000) -- 10ms
      end

      assert.is.equal(10000, h:count())
      assert.is.equal(10000000, h:min())
      assert.is.equal(10000000, h:max())

      local pct = h:percentiles()
      -- min and max are exact
      assert.is.equal(10000000, pct[1])
      assert.is.equal(10000000, pct[100])
      -- interior percentiles are bucket midpoints (~0.8% error)
      assert.is_truthy(math.abs(pct[50] - 10000000) / 10000000 < 0.02)
    end)
  end)

  describe('wide dynamic range', function()
    it('handles values across many orders of magnitude', function()
      local h = Histogram:new()
      h:record(1000) -- 1µs
      h:record(1000000) -- 1ms
      h:record(1000000000) -- 1s

      assert.is.equal(3, h:count())
      assert.is.equal(1000, h:min())
      assert.is.equal(1000000000, h:max())

      local pct = h:percentiles()
      assert.is.equal(100, #pct)
      -- p1 is the bucket midpoint near the smallest value
      assert.is_truthy(math.abs(pct[1] - 1000) / 1000 < 0.01)
      -- p100 is clamped to exact max
      assert.is.equal(1000000000, pct[100])
    end)
  end)

  describe('data retention', function()
    it('never loses observations regardless of count', function()
      local h = Histogram:new()
      for i = 1, 1000000 do
        h:record(i)
      end
      assert.is.equal(1000000, h:count())
    end)
  end)

  describe('edge cases', function()
    it('handles zero values', function()
      local h = Histogram:new()
      h:record(0)
      h:record(0)
      assert.is.equal(2, h:count())
      assert.is.equal(0, h:min())
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
      h:record(1e12) -- 1000 seconds
      assert.is.equal(1e12, h:min())
      assert.is.equal(1e12, h:max())
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
      -- p50 should be near v (the bulk of observations)
      assert.is_truthy(math.abs(pct[50] - v) / v < 0.01)
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
    end)
  end)
end)
