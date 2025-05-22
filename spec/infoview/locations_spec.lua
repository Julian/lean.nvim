local Element = require('lean.tui').Element
local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe('Pin.selectable', function()
  it(
    'returns selectable expressions from the infoview',
    helpers.clean_buffer(
      [[
      example (h : 37 < 73) : 1 + 2 = 3 := by
        rfl
    ]],
      function()
        helpers.search 'rfl'
        helpers.wait_for_loading_pins()

        local pin = infoview.get_current_infoview().info.pin
        assert.are.same(
          { 'h', '37 < 73', '37', '73', '1 + 2 = 3', '1 + 2', '1', '2', '3' },
          pin:selectable():map(Element.to_string):totable()
        )
      end
    )
  )
end)
