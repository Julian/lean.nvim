local Histogram = require 'std.histogram'
local kitty = require 'kitty'
local plot = require 'tui.plot'

describe('tui.plot', function()
  describe('scatter', function()
    it('returns nil when kitty is unavailable', function()
      if kitty.available() then
        pending 'kitty is available in this terminal'
        return
      end
      assert.is.Nil(plot.scatter { 1, 2, 3 })
    end)

    it('returns nil for fewer than 2 data points', function()
      assert.is.Nil(plot.scatter {})
      assert.is.Nil(plot.scatter { 42 })
    end)

    it('returns an Element with overlay when kitty is available', function()
      if not kitty.available() then
        pending 'kitty is not available in this terminal'
        return
      end
      local el = plot.scatter { 1, 2, 3, 4, 5 }
      assert.is_not.Nil(el)
      assert.is_not.Nil(el.overlay)
      assert.is_truthy(el.overlay.width > 0)
      assert.is.equal(120, el.overlay.height)
      assert.is.equal(32, el.overlay.format)
    end)

    it('respects custom dimensions', function()
      if not kitty.available() then
        pending 'kitty is not available in this terminal'
        return
      end
      local el = plot.scatter({ 1, 2, 3 }, { width = 200, height = 80 })
      assert.is.equal(200, el.overlay.width)
      assert.is.equal(80, el.overlay.height)
    end)

    it('handles constant data without crashing', function()
      if not kitty.available() then
        pending 'kitty is not available in this terminal'
        return
      end
      local el = plot.scatter { 5, 5, 5, 5, 5 }
      assert.is_not.Nil(el)
    end)
  end)

  describe('percentile_distribution', function()
    local function histogram_with_uniform_data()
      local h = Histogram:new()
      for i = 1, 10000 do
        h:record(i * 1000)
      end
      return h
    end

    it('returns nil when kitty is unavailable', function()
      if kitty.available() then
        pending 'kitty is available in this terminal'
        return
      end
      assert.is.Nil(plot.percentile_distribution(histogram_with_uniform_data()))
    end)

    it('returns nil for an empty histogram', function()
      assert.is.Nil(plot.percentile_distribution(Histogram:new()))
    end)

    it('renders with log-scaled x-axis and labels', function()
      if not kitty.available() then
        pending 'kitty is not available in this terminal'
        return
      end
      local el = plot.percentile_distribution(histogram_with_uniform_data())
      assert.is_not.Nil(el)
      -- Should contain the image and label text.
      local text = el:to_string()
      assert.is_truthy(text:find '50%%')
      assert.is_truthy(text:find '90%%')
    end)
  end)
end)
