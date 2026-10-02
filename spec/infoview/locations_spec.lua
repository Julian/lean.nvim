local Element = require('lean.tui').Element
local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'
local async = require 'std.async'

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
        helpers.wait:for_ready_infoview()

        local pin = infoview.get_current_infoview().pin
        assert.are.same(
          { 'h', '37 < 73', '37', '73', '1 + 2 = 3', '1 + 2', '1', '2', '3' },
          pin:selectable():map(Element.to_string):totable()
        )
      end
    )
  )
end)

describe('Locations.clear', function()
  it(
    'does not error after the source window closes',
    helpers.clean_buffer(
      [[
        example : 1 = 1 ∧ 1 = 1 := by
          constructor
          · rfl
          · rfl
      ]],
      function()
        helpers.search '·'
        local iv = infoview.get_current_infoview()
        helpers.wait:for_ready_infoview(iv)
        assert.matches('2 goals', table.concat(iv:get_lines(), '\n'))

        vim.cmd.normal 'ZQ'
        assert.is_false(iv.last_window:is_valid())
        assert.current_window.is(iv.window)
        assert.has_error(function()
          async.capture_errors(function()
            helpers.feed '<Esc>'
          end)
        end, 'async.capture_errors: expected coroutine errors but none occurred')
      end
    )
  )
end)
