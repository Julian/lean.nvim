local project = require('spec.fixtures').project

require('lean').setup { ft = { nomodifiable = {} } }

describe('nomodifable', function()
  it('marks files modifiable', function()
    vim.cmd.edit(project.child 'foo.lean')
    assert.is_truthy(vim.bo.modifiable)
  end)
end)
