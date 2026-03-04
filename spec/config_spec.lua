local config = require 'lean.config'
local saved_config = require 'lean.config'()

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

  it('demonstrate proper instantiation of lean.config', function()
    require('lean').setup { goal_markers = { accomplished = "✓", }, }

    -- after setup(), vim.g.lean_config has been updated with opts.
    assert.are.same(vim.g.lean_config.goal_markers.accomplished, '✓')
    -- similarly, evaluating the lean.config function returns vim.g.lean_config merged with defaults.
    assert.are.same(config().goal_markers.accomplished, '✓')

    -- however, evaluating config() at file-local require-time is too early;
    -- it copies the value of vim.g.lean_config before it can be fully set up.
    assert.are.same(saved_config.goal_markers.accomplished, '🎉')
  end)
end)
