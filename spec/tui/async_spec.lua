local Buffer = require 'std.nvim.buffer'

require 'spec.helpers'

local async = require 'std.async'
local Element = require('lean.tui').Element

describe('BufRenderer with async elements', function()
  it('can render an async element that resolves later', function()
    local buffer = Buffer.create { scratch = true }

    local async_element, on_result = Element.async {}
    local root = Element:new {
      children = {
        Element:new { text = 'hello ' },
        async_element,
        Element:new { text = ' world' },
      },
    }
    local renderer = root:renderer { buffer = buffer }

    renderer:render()
    assert.contents.are { 'hello  world', buffer = buffer }

    on_result(Element:new { text = 'async' })
    assert.contents.are { 'hello async world', buffer = buffer }
  end)
end)

describe('async.capture_errors', function()
  it('captures errors from coroutines that crash', function()
    local errors = async.capture_errors(function()
      async.run(function()
        error 'boom'
      end)
    end)
    assert.are.equal(1, #errors)
    assert.is_truthy(errors[1]:match 'boom')
  end)

  it('errors when no async errors occur', function()
    assert.has_error(function()
      async.capture_errors(function()
        async.run(function() end)
      end)
    end, 'async.capture_errors: expected coroutine errors but none occurred')
  end)

  it('suppresses rethrow during capture', function()
    local errors = async.capture_errors(function()
      async.run(function()
        error 'suppressed'
      end)
    end)
    assert.are.equal(1, #errors)
  end)

  it('nests correctly', function()
    local outer = async.capture_errors(function()
      async.run(function()
        error 'outer'
      end)
      local inner = async.capture_errors(function()
        async.run(function()
          error 'inner'
        end)
      end)
      assert.are.equal(1, #inner)
      assert.is_truthy(inner[1]:match 'inner')
    end)
    assert.are.equal(1, #outer)
    assert.is_truthy(outer[1]:match 'outer')
  end)

  it('restores state when fn throws synchronously', function()
    local outer = async.capture_errors(function()
      async.run(function()
        error 'outer'
      end)
      pcall(async.capture_errors, function()
        error 'sync throw'
      end)
    end)
    assert.are.equal(1, #outer)
    assert.is_truthy(outer[1]:match 'outer')
  end)
end)

describe('async.join', function()
  it('returns each function`s results in order', function()
    local out
    async.run(function()
      out = async.join {
        function()
          return 1
        end,
        function()
          return 'a', 'b'
        end,
        function()
          return true
        end,
      }
    end)
    assert.are.same({ { 1 }, { 'a', 'b' }, { true } }, out)
  end)

  it('returns an empty list when given no functions', function()
    local out
    async.run(function()
      out = async.join {}
    end)
    assert.are.same({}, out)
  end)

  it('runs functions concurrently — all start before any completes', function()
    local started = 0
    local complete_a = async.event()
    local complete_b = async.event()
    local done = false

    async.run(function()
      async.join {
        function()
          started = started + 1
          complete_a.wait()
        end,
        function()
          started = started + 1
          complete_b.wait()
        end,
      }
      done = true
    end)

    assert.are.equal(2, started)
    assert.is_false(done)
    complete_a.set()
    assert.is_false(done)
    complete_b.set()
    assert.is_true(done)
  end)

  it('completes synchronously when no function yields', function()
    local done = false
    async.run(function()
      async.join {
        function() end,
        function() end,
      }
      done = true
    end)
    assert.is_true(done)
  end)

  it('propagates an error from a synchronous child to the parent', function()
    local errs = async.capture_errors(function()
      async.run(function()
        async.join {
          function()
            error 'boom'
          end,
          function() end,
        }
      end)
    end)
    assert.are.equal(1, #errs)
    assert.is_truthy(errs[1]:match 'boom')
  end)

  it('propagates an error from an async child after siblings finish', function()
    local sibling_done = false
    local complete = async.event()
    local errs = async.capture_errors(function()
      async.run(function()
        async.join {
          function()
            complete.wait()
            error 'boom'
          end,
          function()
            sibling_done = true
          end,
        }
      end)
      assert.is_true(sibling_done)
      complete.set()
    end)
    assert.are.equal(1, #errs)
    assert.is_truthy(errs[1]:match 'boom')
  end)

  it('surfaces only the first error when multiple children error', function()
    local errs = async.capture_errors(function()
      async.run(function()
        async.join {
          function()
            error 'first'
          end,
          function()
            error 'second'
          end,
        }
      end)
    end)
    assert.are.equal(1, #errs)
    assert.is_truthy(errs[1]:match 'first')
    assert.is_falsy(errs[1]:match 'second')
  end)
end)
