local helpers = require 'spec.helpers'
local rpc = require 'lean.rpc'

require('lean').setup {
  progress_bars = { enable = false },
  debug = { rpc_history = 10 },
}

describe('rpc.sessions', function()
  it(
    'tracks call counts and timing after RPC calls',
    helpers.clean_buffer(
      [[
        example : 37 = 37 := by
          sorry
      ]],
      function()
        helpers.search 'sorry'
        assert.infoview_contents.are [[
          ⊢ 37 = 37]]

        local all = rpc.sessions()
        assert.is_not.equal(next(all), nil)

        for _, info in pairs(all) do
          assert.is.truthy(info.alive)
          local m = info.metrics
          assert.is.truthy(m.call_count > 0)
          assert.is.truthy(m.total_duration_ns > 0)
          assert.is.truthy(m.max_duration_ns > 0)
          assert.is.truthy(m.min_duration_ns > 0)
          assert.is.truthy(m.created_at > 0)
          assert.is.truthy(m.connect_duration_ns > 0)
        end
      end
    )
  )

  it(
    'records request history when rpc_history is enabled',
    helpers.clean_buffer(
      [[
        example : 37 = 37 := by
          sorry
      ]],
      function()
        helpers.search 'sorry'
        assert.infoview_contents.are [[
          ⊢ 37 = 37]]

        local uri = vim.uri_from_bufnr(0)
        local history = rpc.history(uri)
        assert.is_not.Nil(history)
        assert.is.truthy(#history > 0)

        local entry = history[1]
        assert.is.truthy(entry.method)
        assert.is.truthy(entry.start_ns > 0)
        assert.is.truthy(entry.duration_ns > 0)
        assert.is.Nil(entry.error)
      end
    )
  )

  it(
    'tracks errors by code for sessions that encounter errors',
    helpers.clean_buffer(
      [[
        example : 37 = 37 := by
          sorry
      ]],
      function()
        helpers.search 'sorry'
        assert.infoview_contents.are [[
          ⊢ 37 = 37]]

        -- Successful calls shouldn't have errors; verify the structure exists.
        local all = rpc.sessions()
        for _, info in pairs(all) do
          local m = info.metrics
          assert.is.equal(type(m.errors_by_code), 'table')
          -- error_count should be consistent with errors_by_code
          local sum = 0
          for _, count in pairs(m.errors_by_code) do
            sum = sum + count
          end
          assert.is.equal(m.error_count, sum)
        end
      end
    )
  )
end)

describe('rpc.history ring buffer', function()
  it(
    'records entries and respects the configured size limit',
    helpers.clean_buffer(
      [[
        example : 37 = 37 := by
          sorry
      ]],
      function()
        helpers.search 'sorry'
        assert.infoview_contents.are [[
          ⊢ 37 = 37]]

        local uri = vim.uri_from_bufnr(0)
        local history = rpc.history(uri)
        assert.is_not.Nil(history)
        assert.is.truthy(#history > 0)
        assert.is.truthy(#history <= 10)
        for _, entry in ipairs(history) do
          assert.is.truthy(entry.method)
          assert.is.truthy(entry.start_ns > 0)
          assert.is.truthy(entry.duration_ns >= 0)
        end
      end
    )
  )
end)
