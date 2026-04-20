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
