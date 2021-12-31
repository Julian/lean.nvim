---@brief [[
--- Tests for the automatic updating of infoview contents.
---
--- When debugging tests here, if you're confused about something not updating,
--- sprinkle print debugging around `infoview.Pin:__update`. Don't forget some
--- functions are run asynchronously, so if you don't see an update, it may be
--- because a test has finished before the promise fires, which usually means
--- the test needs to wait for an update (using e.g.
---`helpers.wait_for_infoview_contents`).
---
--- Note that unfortunately as "usual" for neovim tests, those below are not
--- independent, so if you see unexpected behavior even though tests below
--- pass, you may be encountering a global-state-related bug which isn't
--- tickled by the precise sequence below.
---
--- Nevertheless, each test attempts to at least describe what preconditions it
--- wants (as guard assertions), so they should in theory be reorderable, or
--- ultimately perhaps separable into different files if performance isn't
--- terrible when doing so.
---@brief ]]

local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')
local helpers = require('tests.helpers')


helpers.setup {
  lsp = { enable = true },
  infoview = {
    autoopen = true,
    autopause = false,
    use_widgets = true,
  },
}
describe('infoview content (auto-)update', function()

  local lean_window

  it("shows the initial cursor location's infoview", function(_)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))

    helpers.edit_lean_buffer(fixtures.lean_project.path .. '/Test/Squares.lean')
    lean_window = vim.api.nvim_get_current_win()
    -- In theory we don't care where we are, but the right answer changes
    assert.are.same(vim.api.nvim_win_get_cursor(0), {1, 0})

    helpers.wait_for_infoview_contents('^1')
    -- FIXME: The no info doesn't seem to show when not headless.
    --        Also trailing extra newline.
    assert.infoview_contents.are[[
      No info.

      ▶ 1:1-1:6: information:
      1

    ]]
  end)

  it('updates when the cursor moves', function(_)
    assert.are_not.same(vim.api.nvim_win_get_cursor(0), {3, 0})

    helpers.move_cursor{ to = {3, 0} }
    helpers.wait_for_infoview_contents('^9')
    -- FIXME: The no info doesn't seem to show when not headless.
    --        Also trailing extra newline.
    assert.infoview_contents.are[[
      No info.

      ▶ 3:1-3:6: information:
      9.000000

    ]]
  end)

  it('is shared between separate windows', function(_)
    assert.is.equal(lean_window, vim.api.nvim_get_current_win())

    vim.cmd('split')
    local second_window = vim.api.nvim_get_current_win()
    assert.are.same(vim.api.nvim_win_get_cursor(0), {3, 0})
    helpers.wait_for_infoview_contents('^9')
    assert.infoview_contents.are[[
      No info.

      ▶ 3:1-3:6: information:
      9.000000

    ]]

    helpers.move_cursor{ to = {1, 0} }
    helpers.wait_for_infoview_contents('^1')
    assert.infoview_contents.are[[
      No info.

      ▶ 1:1-1:6: information:
      1

    ]]

    -- Now switch back to the other window and...
    vim.cmd[[wincmd p]]
    helpers.wait_for_infoview_contents('^9')
    assert.infoview_contents.are[[
      No info.

      ▶ 3:1-3:6: information:
      9.000000

    ]]

    vim.api.nvim_win_close(second_window, false)
  end)

  it('does not update for non-Lean buffers', function(_)
    assert.is.equal(lean_window, vim.api.nvim_get_current_win())

    local original_lines = infoview.get_current_infoview():get_lines()
    vim.cmd('split some_non_lean_file.tmp')
    helpers.insert('some stuff')
    assert.are.same(original_lines, infoview.get_current_infoview():get_lines())

    vim.cmd('close!')
  end)

  it('does not error while closed and continues updating when reopened', function(_)
    assert.are.same_elements(
      { lean_window, infoview.get_current_infoview().window },
      vim.api.nvim_tabpage_list_wins(0)
    )
    assert.are_not.same(vim.api.nvim_win_get_cursor(0), {1, 0})

    infoview.get_current_infoview():close()

    -- Move around a bit.
    helpers.move_cursor{ to = {1, 0} }
    helpers.move_cursor{ to = {2, 0} }
    helpers.move_cursor{ to = {1, 0} }

    infoview.get_current_infoview():open()
    helpers.wait_for_infoview_contents('^1')
    assert.infoview_contents.are[[
      No info.

      ▶ 1:1-1:6: information:
      1

    ]]

    helpers.move_cursor{ to = {3, 0} }
    helpers.wait_for_infoview_contents('^9')
    assert.infoview_contents.are[[
      No info.

      ▶ 3:1-3:6: information:
      9.000000

    ]]
  end)

  describe('in multiple tabs', function()
    it('updates separate infoviews independently', function(_)
      local tab1_infoview = infoview.get_current_infoview()
      assert.same.elements(
        { lean_window, tab1_infoview.window },
        vim.api.nvim_tabpage_list_wins(0)
      )

      helpers.move_cursor{ to = {1, 0} }
      helpers.wait_for_infoview_contents('^1')
      assert.infoview_contents.are[[
        No info.

        ▶ 1:1-1:6: information:
        1

      ]]

      vim.cmd('tabnew' .. fixtures.lean_project.path .. '/Test/Squares.lean')
      helpers.move_cursor{ to = {3, 0} }
      helpers.wait_for_infoview_contents('^9')
      assert.infoview_contents.are[[
        No info.

        ▶ 3:1-3:6: information:
        9.000000

      ]]

      -- But the first tab's contents are unchanged even without re-entering.
      assert.infoview_contents.are{
        [[
          No info.

          ▶ 1:1-1:6: information:
          1

        ]],
        infoview = tab1_infoview
      }
    end)

    it('updates separate infoviews independently when one is closed', function(_)
      local tab2 = vim.api.nvim_get_current_tabpage()
      assert.is_not.equal(vim.api.nvim_win_get_tabpage(lean_window), tab2)

      infoview.get_current_infoview():close()
      vim.cmd('tabprevious')

      helpers.move_cursor{ to = {3, 0} }
      helpers.wait_for_infoview_contents('^9')
      assert.infoview_contents.are[[
        No info.

        ▶ 3:1-3:6: information:
        9.000000

      ]]

      helpers.move_cursor{ to = {1, 0} }
      helpers.wait_for_infoview_contents('^1')
      assert.infoview_contents.are[[
        No info.

        ▶ 1:1-1:6: information:
        1

      ]]

      vim.cmd(tab2 .. 'tabclose')
      assert.is.equal(
        vim.api.nvim_win_get_tabpage(lean_window),
        vim.api.nvim_get_current_tabpage()
      )
    end)
  end)
end)
