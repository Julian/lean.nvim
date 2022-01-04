---@brief [[
---Tests for the console UI framework in isolation (from a Lean file or Lean widgets).
---@brief ]]

local Element = require('lean.widgets').Element

describe('Element:concat', function()
  it('creates an Element concatenated by a separator', function()
    local foo = Element:new{ text = "foo", name = "foo-name" }
    local bar = Element:new{ text = "bar bar", name = "bar-name" }
    local baz = Element:new{ name = "baz-name" }

    local element = Element:concat({ foo, bar, baz }, '\n\n')

    assert.is.same(
      Element:new{
        children = {
          foo,
          Element:new{ text = '\n\n' },
          bar,
          Element:new{ text = '\n\n' },
          baz,
        },
      },
      element
    )
  end)
end)

describe('Element:renderer', function()
  pending('creates a BufRenderer rendering the element', function()
    -- Creating BufRenderers currently has lots of side effects.
  end)
end)
