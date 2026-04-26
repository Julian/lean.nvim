local Buffer = require 'std.nvim.buffer'

local goals = require 'lean.goals'

---Build a fake ReconnectingSubsession for `goals.at`.
---@param uri string
---@param session table sentinel identifying the underlying RPC session
---@param call_count { n: integer } a counter incremented on each call
local function fake_sess(uri, session, call_count)
  return {
    pos = { textDocument = { uri = uri }, position = { line = 0, character = 0 } },
    sess = session,
    getInteractiveGoals = function()
      call_count.n = call_count.n + 1
      return { goals = { { mvarId = '_uniq.' .. call_count.n } } }
    end,
  }
end

describe('goals.at', function()
  it('caches goals across calls within the same session', function()
    local buffer = Buffer.create {
      listed = false,
      scratch = true,
      name = vim.fn.tempname() .. '.lean',
    }
    local uri = vim.uri_from_bufnr(buffer.bufnr)
    local session = {}
    local call_count = { n = 0 }

    local first = goals.at(fake_sess(uri, session, call_count))
    local second = goals.at(fake_sess(uri, session, call_count))

    assert.are.equal(first, second)
    assert.are.equal(1, call_count.n)
  end)

  it('refetches when the underlying RPC session has changed', function()
    local buffer = Buffer.create {
      listed = false,
      scratch = true,
      name = vim.fn.tempname() .. '.lean',
    }
    local uri = vim.uri_from_bufnr(buffer.bufnr)
    local call_count = { n = 0 }

    local first = goals.at(fake_sess(uri, {}, call_count))
    local second = goals.at(fake_sess(uri, {}, call_count))

    assert.are_not.equal(first, second)
    assert.are.equal(2, call_count.n)
  end)
end)
