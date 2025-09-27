local fixtures = require 'spec.fixtures'

require('lean').setup {}

---Get all buffer-local autocmds for this buffer.
---
---Filter out some autocmds which come from Neovim core and seem to pop up
---randomly.
local function autocmds()
  return vim
    .iter(vim.api.nvim_get_autocmds { buffer = 0 })
    :filter(function(each)
      return not each.group_name:match '^nvim'
    end)
    :totable()
end

describe('autocmds', function()
  it('do not get duplicated when re-opening the same buffer multiple times', function()
    local initial = autocmds()

    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    local lean_autocmds = autocmds()
    assert.is_not.equal(#initial, #lean_autocmds, 'Expected some autocmds to be created')

    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    local after_reopen = autocmds()
    assert.is.equal(
      #lean_autocmds,
      #after_reopen,
      ('Duplicate autocmds were attached.\nWas:%s\n\nNow:%s\n'):format(
        vim.inspect(lean_autocmds),
        vim.inspect(after_reopen)
      )
    )
  end)
end)
