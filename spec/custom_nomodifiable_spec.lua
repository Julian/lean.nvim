local project = require('spec.fixtures').project

require('lean').setup {
  ft = {
    nomodifiable = { 'foo.lean' },
  },
}

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
