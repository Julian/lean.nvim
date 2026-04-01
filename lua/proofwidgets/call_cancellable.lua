---@mod proofwidgets.call_cancelable

---@brief [[
--- A reimplementation of ProofWidgets' cancellable RPC calling.
---
--- See https://github.com/leanprover-community/ProofWidgets4/blob/main/widget/src/cancellable.ts
---@brief ]]

local async = require 'std.async'

---@generic T
---@generic S
---@param sess ReconnectingSubsession
---@param name string the method to call
---@param params T
---@param callback fun(result: S):nil
---@param retries? integer the maximum number of attempts to make, 10 by default
---@return fun():nil cancel a callable which can cancel the request before it has finished
return function(sess, name, params, callback, retries)
  async.run(function()
    local id, err = sess:call(name .. '._cancellable', params)
    if err then
      error(err)
    end

    local timer = vim.uv.new_timer()

    local function cancel()
      timer:stop()
      timer:close()
      sess:call('ProofWidgets.cancelRequest', id)
    end

    local remaining = retries or 10
    timer:start(0, 100, function()
      if remaining <= 0 then -- FIXME: move to bottom
        return cancel()
      end
      remaining = remaining - 1

      vim.schedule(function()
        async.run(function()
          local response = sess:call('ProofWidgets.checkRequest', id)
          if response == 'running' then
            return
          end

          timer:stop()
          timer:close()
          callback(response.done.result)
        end)
      end)
    end)

    return cancel
  end)
end
