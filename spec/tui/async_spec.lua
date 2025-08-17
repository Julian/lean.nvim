local Buffer = require 'std.nvim.buffer'

require 'spec.helpers'

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
