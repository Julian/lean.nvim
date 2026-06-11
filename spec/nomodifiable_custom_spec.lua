local project = require('spec.fixtures').project

---@type lean.Config
vim.g.lean_config = { ft = { nomodifiable = { 'foo.lean' } } }

-- These tests do not exercise the infoview, so avoid (automatically)
-- opening ones, reducing load.
vim.g.lean_config =
  vim.tbl_deep_extend('force', vim.g.lean_config, { infoview = { autoopen = false } })

describe('nomodifable', function()
  it('marks a nomodifiable file not modifiable', function()
    vim.cmd.edit(project.child 'foo.lean')
    assert.is_falsy(vim.bo.modifiable)
  end)

  it('marks other files modifiable', function()
    vim.cmd.edit(project.child 'bar.lean')
    assert.is_truthy(vim.bo.modifiable)
  end)
end)
