local config = require 'lean.config'

describe('config', function()
  before_each(function()
    vim.g.lean_config = nil
  end)

  it('contains defaults when no user config is set', function()
    assert.are.same(config().mappings, false)
  end)

  it('merges user config when set', function()
    vim.g.lean_config = { mappings = true }
    assert.are.same(config().mappings, true)
  end)
end)
