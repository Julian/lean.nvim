describe('lean.setup', function()
  it('Does not crash when loaded twice', function()
    require('lean').setup {}
    require('lean').setup {}
  end)

  it('does not warn when Neovim is new enough', function()
    local lean = require 'lean'
    assert.is_false(
      vim.version.lt(vim.version(), lean.MIN_SUPPORTED_NVIM),
      'tests are running on an unsupported Neovim, cannot test this'
    )

    local warned = false
    local orig_notify = vim.notify
    vim.notify = function(_, level)
      if level == vim.log.levels.WARN then
        warned = true
      end
    end

    package.loaded['lean'] = nil
    require 'lean'

    vim.notify = orig_notify

    assert.is_false(warned)
  end)

  it('warns when Neovim is too old', function()
    -- Temporarily pretend we are running an old Neovim.
    local min_version = require('lean').MIN_SUPPORTED_NVIM

    local warned
    local orig_notify = vim.notify
    vim.notify = function(msg, level)
      if level == vim.log.levels.WARN then
        warned = msg
      end
    end

    local orig_lt = vim.version.lt
    local lt_version_arg
    vim.version.lt = function(_, v)
      lt_version_arg = v
      return true
    end

    -- Unload the module so the top-level check runs again on re-require.
    package.loaded['lean'] = nil
    local lean = require 'lean'

    vim.version.lt = orig_lt
    vim.notify = orig_notify

    assert.equals(min_version, lt_version_arg)
    assert.is_not_nil(warned)
    assert.has_match(vim.pesc(lean.MIN_SUPPORTED_NVIM), warned)
  end)
end)
