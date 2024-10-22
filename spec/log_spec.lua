local messages
---@type lean.Config
vim.g.lean_config = {
  log = function(_, message)
    table.insert(messages, message)
  end,
}

local log = require 'lean.log'

describe('log', function()
  before_each(function()
    messages = {}
  end)

  it('logs messages', function()
    log:trace { message = 'test 123' }
    vim.wait(0, function()
      return not vim.tbl_isempty(messages)
    end)
    assert.are.same({ { message = 'test 123' } }, messages)
  end)
end)
