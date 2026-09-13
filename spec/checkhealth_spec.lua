require 'spec.helpers'

local dedent = require('std.text').dedent

describe('checkhealth', function()
  it('passes the health check', function()
    vim.cmd.checkhealth 'lean'

    -- Healthchecks run asynchronously on Neovim 0.13+, which marks the buffer
    -- nomodifiable once they're done.
    local succeeded = vim.wait(10000, function()
      return not vim.bo.modifiable
    end)
    assert.message('checkhealth never finished').is_true(succeeded)

    assert.has_match(
      dedent [[
        .*lean.nvim.*
        .*- .*OK.* Neovim is new enough.
        .*- .*vim.version().*
        .*- .*OK.* Lake is runnable.
        .*-.* `lake ----version`: .*Lean .*version .+
        .*- .*OK.* lean.nvim's plugin files have run.
      ]],
      table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    )
  end)
end)
