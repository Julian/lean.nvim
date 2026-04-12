local throttle = require 'std.throttle'

describe('throttle', function()
  it('fires immediately on the first call', function()
    local calls = {}
    local fn = throttle(50, function(x)
      table.insert(calls, x)
    end)

    fn 'a'
    assert.are.same({ 'a' }, calls)
  end)

  it('suppresses calls during the cooldown', function()
    local calls = {}
    local fn = throttle(50, function(x)
      table.insert(calls, x)
    end)

    fn 'a'
    fn 'b'
    fn 'c'
    assert.are.same({ 'a' }, calls)
  end)

  it('flushes the latest suppressed call after the cooldown', function()
    local calls = {}
    local fn = throttle(10, function(x)
      table.insert(calls, x)
    end)

    fn 'a'
    fn 'b'
    fn 'c'
    assert.are.same({ 'a' }, calls)

    vim.wait(50, function()
      return #calls > 1
    end)
    assert.are.same({ 'a', 'c' }, calls)
  end)

  it('fires immediately again after the cooldown expires with no pending call', function()
    local calls = {}
    local fn = throttle(10, function(x)
      table.insert(calls, x)
    end)

    fn 'a'
    vim.wait(50, function() end)
    fn 'b'
    assert.are.same({ 'a', 'b' }, calls)
  end)

  it('passes through directly when cooldown is 0', function()
    local calls = {}
    local fn = throttle(0, function(x)
      table.insert(calls, x)
    end)

    fn 'a'
    fn 'b'
    fn 'c'
    assert.are.same({ 'a', 'b', 'c' }, calls)
  end)
end)
