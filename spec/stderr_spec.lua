local project = require('spec.fixtures').project

describe('lean.stderr', function()
  it('captures stderr messages from the Lean language server', function()
    local original = vim.lsp.log.error

    require('lean').setup {}
    assert.is.equal(original, vim.lsp.log.error)

    vim.cmd.edit { project.some_existing_file, bang = true }

    assert.is_not.equal(original, vim.lsp.log.error)
  end)
end)
