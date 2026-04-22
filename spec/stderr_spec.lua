local fixtures = require 'spec.fixtures'
local helpers = require 'spec.helpers'

local received

require('lean').setup {
  stderr = {
    on_lines = function(chunk)
      table.insert(received, chunk)
    end,
  },
}

describe('lean.stderr', function()
  before_each(function()
    received = {}
  end)

  it(
    'captures dbg_trace output within a project',
    helpers.clean_buffer(
      [[
        set_option stderrAsMessages false
        #eval dbg_trace "hello from lake stderr"; (0 : Nat)
      ]],
      function()
        helpers.wait:for_diagnostics()
        assert
          .message('never received dbg_trace output on stderr, got: ' .. vim.inspect(received))
          .True(vim.iter(received):any(function(chunk)
            return chunk:find 'hello from lake stderr' ~= nil
          end))
      end
    )
  )

  it(
    'captures dbg_trace output outside a project',
    helpers.clean_buffer(
      [[
        set_option stderrAsMessages false
        #eval dbg_trace "hello from lean stderr"; (0 : Nat)
      ]],
      function()
        helpers.wait:for_diagnostics()
        assert
          .message('never received dbg_trace output on stderr, got: ' .. vim.inspect(received))
          .True(vim.iter(received):any(function(chunk)
            return chunk:find 'hello from lean stderr' ~= nil
          end))
      end,
      fixtures.standalone
    )
  )
end)
