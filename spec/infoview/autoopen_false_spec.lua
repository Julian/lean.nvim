local Tab = require 'std.nvim.tab'
local Window = require 'std.nvim.window'

local fixtures = require 'spec.fixtures'
local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup { infoview = { autoopen = false } }

describe('infoview', function()
  local lean_window

  it('does not automatically open infoviews', function()
    assert.is.equal(1, #Tab:current():windows())
    vim.cmd.edit { fixtures.project.child 'Example.lean', bang = true }
    -- FIXME: This obviously shouldn't require running twice, but without
    --        it, somehow the test run differs from interactive use!
    --        Specifically, ft.detect doesn't run at all until the second
    --        time a file is opened :/. This must be related to what I've
    --        observed about `make nvim` -- that if you edit a file, you
    --        have to open it twice to open the infoview, so when we fix
    --        that, this should be fixed as well -- but for now, this needs
    --        to be here twice to prevent regressions like #245.
    --        To know whether you can remove this, undo the change from #245
    --        and ensure this test properly fails.
    vim.cmd.edit { fixtures.project.child 'Example.lean', bang = true }
    lean_window = Window:current()
    assert.windows.are { lean_window }
  end)

  it('allows infoviews to be manually opened', function()
    assert.windows.are { lean_window }
    helpers.search 'square 4'
    infoview.open()
    assert.windows.are { lean_window, infoview.get_current_infoview().window }
    assert.infoview_contents.are [[
      ▼ expected type (3:28-3:36)
      ⊢ Nat
    ]]
    infoview.close()
  end)
end)
