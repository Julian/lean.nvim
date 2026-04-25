local humanize = require 'std.humanize'

describe('std.humanize', function()
  describe('duration', function()
    it('formats nanoseconds', function()
      assert.is.equal('0ns', humanize.duration(0))
      assert.is.equal('500ns', humanize.duration(500))
      assert.is.equal('999ns', humanize.duration(999))
    end)

    it('formats microseconds', function()
      assert.is.equal('1µs', humanize.duration(1e3))
      assert.is.equal('500µs', humanize.duration(500e3))
    end)

    it('formats milliseconds', function()
      assert.is.equal('1.0ms', humanize.duration(1e6))
      assert.is.equal('42.5ms', humanize.duration(42.5e6))
    end)

    it('formats seconds', function()
      assert.is.equal('1.00s', humanize.duration(1e9))
      assert.is.equal('3.14s', humanize.duration(3.14e9))
    end)
  end)
end)
