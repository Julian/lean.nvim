local Ringbuf = require 'std.ringbuf'

describe('std.ringbuf', function()
  it('stores and retrieves items in order', function()
    local r = Ringbuf:new(4)
    r:push 'a'
    r:push 'b'
    r:push 'c'
    assert.are.same({ 'a', 'b', 'c' }, r:items())
  end)

  it('overwrites oldest items when full', function()
    local r = Ringbuf:new(3)
    r:push 'a'
    r:push 'b'
    r:push 'c'
    r:push 'd'
    assert.are.same({ 'b', 'c', 'd' }, r:items())
  end)

  it('handles multiple wraps', function()
    local r = Ringbuf:new(3)
    r:push 'a'
    r:push 'b'
    r:push 'c'
    r:push 'd'
    r:push 'e'
    r:push 'f'
    assert.are.same({ 'd', 'e', 'f' }, r:items())
  end)

  it('returns items non-destructively', function()
    local r = Ringbuf:new(3)
    r:push 'a'
    r:push 'b'
    assert.are.same({ 'a', 'b' }, r:items())
    assert.are.same({ 'a', 'b' }, r:items())
  end)

  it('returns an empty list when empty', function()
    local r = Ringbuf:new(3)
    assert.are.same({}, r:items())
  end)

  it('clears all items', function()
    local r = Ringbuf:new(3)
    r:push 'a'
    r:push 'b'
    r:clear()
    assert.are.same({}, r:items())
    r:push 'c'
    assert.are.same({ 'c' }, r:items())
  end)
end)
