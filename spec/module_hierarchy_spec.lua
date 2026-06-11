---@brief [[
--- Tests for the `:LeanModuleImports` / `:LeanModuleImportedBy` commands and
--- the underlying module hierarchy LSP requests (Lean >= 4.22).
---@brief ]]

local Window = require 'std.nvim.window'

local fixtures = require 'spec.fixtures'
local helpers = require 'spec.helpers'

vim.g.lean_config =
  vim.tbl_deep_extend('force', vim.g.lean_config, { infoview = { autoopen = false } })

describe('module hierarchy', function()
  it(
    'lists the direct imports of the current file',
    helpers.clean_buffer(function()
      vim.cmd.edit(fixtures.with_widgets:child 'WithWidgets.lean')
      helpers.wait:for_lsp()
      helpers.wait:for_processing()

      local source = Window:current()
      vim.cmd.LeanModuleImports()
      local panel = helpers.wait_for_new_window { source }
      helpers.wait:for_window_contents('^Imports of', panel)

      assert.are.same({
        'Imports of WithWidgets',
        '<Tab> toggle · <CR> open · r refresh',
        '',
        '▶ WithWidgets.FilterDetailsWidget',
        '▶ WithWidgets.GenericRpcWidget',
        '▶ WithWidgets.InteractiveExprWidget',
        '▶ WithWidgets.MarkdownWidget',
        '▶ WithWidgets.NullPropsWidget',
        '▶ WithWidgets.PreWidget',
        '▶ WithWidgets.RefreshWidget',
      }, panel:buffer():lines())

      panel:close()
    end)
  )

  it(
    'indents children when a node is expanded',
    helpers.clean_buffer(function()
      vim.cmd.edit(fixtures.with_widgets:child 'WithWidgets.lean')
      helpers.wait:for_lsp()
      helpers.wait:for_processing()

      local source = Window:current()
      vim.cmd.LeanModuleImports()
      local panel = helpers.wait_for_new_window { source }
      helpers.wait:for_window_contents('^Imports of', panel)

      -- Move to the first foldable arrow. move_cursor (vs nvim_win_set_cursor)
      -- fires CursorMoved synchronously, so the renderer updates its path
      -- before we trigger the toggle.
      local first = vim.fn.search('^▶', 'cnW')
      assert.is.truthy(first > 0, 'expected at least one ▶ row')
      panel:move_cursor { first, 1 }
      helpers.feed '<Tab>'

      local opened_idx
      local opened = vim.wait(2000, function()
        for i, line in ipairs(panel:buffer():lines()) do
          if line:match '^▼' then
            opened_idx = i
            return true
          end
        end
        return false
      end, 50)
      assert.is.truthy(opened, 'expected the expanded foldable to render with ▼')

      -- Children should appear directly below, indented two spaces.
      local next_line = panel:buffer():lines()[opened_idx + 1]
      assert.is.truthy(
        next_line and next_line:match '^  [▶▼]',
        'expected expanded children to be indented under the parent, got: ' .. tostring(next_line)
      )

      panel:close()
    end)
  )

  it(
    'lists the modules that import the current one',
    helpers.clean_buffer(function()
      -- Open the parent first so its imports are tracked by the server.
      vim.cmd.edit(fixtures.with_widgets:child 'WithWidgets.lean')
      helpers.wait:for_lsp()
      helpers.wait:for_processing()

      vim.cmd.edit(fixtures.with_widgets:child 'WithWidgets/RefreshWidget.lean')
      helpers.wait:for_lsp()
      helpers.wait:for_processing()

      local source = Window:current()
      vim.cmd.LeanModuleImportedBy()
      local panel = helpers.wait_for_new_window { source }
      helpers.wait:for_window_contents('^Importers of', panel)

      local lines = panel:buffer():lines()
      assert.are.same('Importers of WithWidgets.RefreshWidget', lines[1])
      assert.is.truthy(
        vim.iter(lines):any(function(line)
          return line == '▶ WithWidgets'
        end),
        'expected WithWidgets to appear in the importedBy tree, got:\n' .. table.concat(lines, '\n')
      )

      panel:close()
    end)
  )

  describe('when the panel is the only window in the only tab', function()
    ---Capture vim.notify calls during `fn`.
    ---@param fn function
    ---@return string[] notifications
    local function capture_notify(fn)
      local notifications = {}
      local original = vim.notify
      vim.notify = function(msg)
        table.insert(notifications, msg)
      end
      local ok, err = pcall(fn)
      vim.notify = original
      assert.is.truthy(ok, err)
      return notifications
    end

    ---Set up a single-tab nvim showing only the panel (source closed).
    ---Returns the panel `Window`. With the source window closed, the panel
    ---buffer (`leaninfo`) has no Lean LSP attached -- this is what the specs
    ---below exercise: the pre-flight bail and the source-window-gone guard.
    local function panel_alone()
      vim.cmd.tabonly { bang = true }
      vim.cmd.only { bang = true } -- and only one window in that tab
      vim.cmd.edit(fixtures.with_widgets:child 'WithWidgets.lean')
      helpers.wait:for_lsp()
      helpers.wait:for_processing()

      local source = Window:current()
      vim.cmd.LeanModuleImports()
      local panel = helpers.wait_for_new_window { source }
      helpers.wait:for_window_contents('^Imports of', panel)
      source:force_close()
      return panel
    end

    ---Restore a normal layout so the next test starts clean.
    local function restore(panel)
      -- The panel is currently the only window. Give it a sibling so we can
      -- close it without taking nvim down.
      vim.cmd.new()
      pcall(function()
        panel:close()
      end)
    end

    it('still focuses an existing same-direction panel', function()
      local panel = panel_alone()

      -- Drop into a fresh empty buffer in a sibling window: it has no Lean
      -- LSP attached either, but re-running the same direction should still
      -- surface the existing panel ("show me my panel") -- the LSP check
      -- is only for actually opening a new one.
      vim.cmd.new()
      vim.cmd.LeanModuleImports()

      assert.is.truthy(Window:current().id == panel.id, 'expected panel to be focused')
      restore(panel)
    end)

    it('refuses to open a new panel and leaves the existing one alone', function()
      local panel = panel_alone()

      -- Cursor is inside the panel (source was closed); the panel buffer has
      -- no Lean LSP attached, so the pre-flight bails before touching the
      -- existing panel.
      local notifications = capture_notify(function()
        vim.cmd.LeanModuleImportedBy()
        vim.wait(200)
      end)

      assert.is.truthy(panel:is_valid(), 'panel should still be open')
      assert.are.same('Imports of WithWidgets', panel:buffer():lines()[1])
      assert.is.truthy(
        vim.iter(notifications):any(function(m)
          return m:match 'No Lean LSP'
        end),
        'expected a "No Lean LSP" notification, got: ' .. vim.inspect(notifications)
      )

      restore(panel)
    end)

    it('refuses to refresh against an unrelated buffer', function()
      local panel = panel_alone()
      panel:make_current()

      local notifications = capture_notify(function()
        helpers.feed 'r'
        vim.wait(200)
      end)

      assert.is.truthy(panel:is_valid(), 'panel should not have been closed')
      assert.is.truthy(
        vim.iter(notifications):any(function(m)
          return m:match 'source window is gone'
        end),
        'expected a "source window is gone" notification, got: ' .. vim.inspect(notifications)
      )

      restore(panel)
    end)
  end)
end)
