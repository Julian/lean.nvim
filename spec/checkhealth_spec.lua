require 'spec.helpers'

local project = require('spec.fixtures').project
local dedent = require('lean._util').dedent

describe('checkhealth', function()
  it('passes the health check when run outside a project', function()
    vim.cmd.checkhealth 'lean'
    assert.has_match(
      dedent [[
        .*lean.nvim.*
        .*- .*OK.* Neovim is new enough.
        .*- .*vim.version().+
        .*- .*OK.* `elan` is runnable.
        .*- .*elan show.+
      ]],
      table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    )
  end)

  it('passes the health check when run from a project', function()
    vim.cmd.lcd(project.root)
    vim.cmd.checkhealth 'lean'
    assert.has_match(
      dedent [[
        .*lean.nvim.*
        .*- .*OK.* Neovim is new enough.
        .*- .*vim.version().*
        .*- .*OK.* `elan` is runnable.
        .*- .*elan show.+
      ]],
      table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    )
  end)
end)
