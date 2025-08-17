require 'spec.helpers'

local Buffer = require 'std.nvim.buffer'
local Element = require('lean.tui').Element

describe('BufRenderer async elements', function()
  it('are tracked in pending_elements', function()
    local buffer = Buffer.create { listed = false, scratch = true }

    local async_el, resolve = Element.async 'test'
    local element = Element:new {
      children = {
        Element:new { text = 'hello ' },
        async_el,
        Element:new { text = ' world' },
      },
    }

    local renderer = element:renderer { buffer = buffer }
    renderer:render()

    assert.are.same({ [async_el] = true }, renderer.pending_elements)
    assert.contents.are { 'hello  world', buffer = buffer }

    resolve(Element:new { text = 'async' })

    assert.contents.are { 'hello async world', buffer = buffer }
    assert.is.empty(renderer.pending_elements)

    buffer:force_delete()
  end)
end)
