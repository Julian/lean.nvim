local debounce = require 'std.debounce'

describe('debounce', function()
  it('fires immediately on the first call', function()
    local calls = {}
    local fn, is_pending = debounce(50, function(x)
      table.insert(calls, x)
    end)

    assert.is_false(is_pending())
    fn 'a'
    assert.are.same({ 'a' }, calls)
    assert.is_false(is_pending())
  end)

  it('suppresses calls during the quiet period and reports pending', function()
    local calls = {}
    local fn, is_pending = debounce(50, function(x)
      table.insert(calls, x)
    end)

    fn 'a'
    assert.is_false(is_pending())
    fn 'b'
    fn 'c'
    assert.are.same({ 'a' }, calls)
    assert.is_true(is_pending())
  end)

  it('flushes the latest suppressed call after the quiet period', function()
    local calls = {}
    local fn, is_pending = debounce(10, function(x)
      table.insert(calls, x)
    end)

    fn 'a'
    fn 'b'
    fn 'c'
    assert.are.same({ 'a' }, calls)
    assert.is_true(is_pending())

    assert.is_true(vim.wait(100, function()
      return #calls > 1
    end))
    assert.are.same({ 'a', 'c' }, calls)
    assert.is_false(is_pending())
  end)

  it('resets the quiet period on each suppressed call', function()
    local calls = {}
    local fn, is_pending = debounce(40, function(x)
      table.insert(calls, x)
    end)

    fn 'a'
    vim.wait(20, function() end)
    fn 'b'
    vim.wait(25, function() end)
    -- 45ms since 'a', but only 25ms since 'b', so 'b' has not flushed yet.
    assert.are.same({ 'a' }, calls)
    assert.is_true(is_pending())

    assert.is_true(vim.wait(100, function()
      return #calls > 1
    end))
    assert.are.same({ 'a', 'b' }, calls)
    assert.is_false(is_pending())
  end)

  it('fires immediately again after the quiet period expires with no pending call', function()
    local calls = {}
    local fn = debounce(10, function(x)
      table.insert(calls, x)
    end)

    fn 'a'
    vim.wait(50, function() end)
    fn 'b'
    assert.are.same({ 'a', 'b' }, calls)
  end)

  it('passes through directly when cooldown is 0', function()
    local calls = {}
    local fn, is_pending = debounce(0, function(x)
      table.insert(calls, x)
    end)

    fn 'a'
    fn 'b'
    fn 'c'
    assert.are.same({ 'a', 'b', 'c' }, calls)
    assert.is_false(is_pending())
  end)
end)
