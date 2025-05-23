require 'spec.helpers'

local dedent = require('std.text').dedent

describe('checkhealth', function()
  it('passes the health check', function()
    vim.cmd.checkhealth 'lean'
    assert.has_match(
      dedent [[
        .*lean.nvim.*
        .*- .*OK.* Neovim is new enough.
        .*- .*vim.version().*
        .*- .*OK.* Lake is runnable.
        .*-.* `lake ----version`: .*Lean .*version .+
      ]],
      table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    )
  end)
end)
