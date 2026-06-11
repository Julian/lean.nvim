local project = require('spec.fixtures').project

vim.g.lean_config = vim.tbl_deep_extend('force', vim.g.lean_config, { ft = { nomodifiable = {} } })

describe('nomodifable', function()
  it('marks files modifiable', function()
    vim.cmd.edit(project.child 'foo.lean')
    assert.is_truthy(vim.bo.modifiable)
  end)
end)
