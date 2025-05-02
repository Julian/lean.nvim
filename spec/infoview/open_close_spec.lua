---@brief [[
--- Tests for the opening and closing of infoviews via command mode, their Lua
--- API, or combinations of the two.
---@brief ]]

require 'spec.helpers'
local Window = require 'std.nvim.window'
local fixtures = require 'spec.fixtures'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe('infoview open/close', function()
  local lean_window

  it('opens', function()
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    lean_window = Window:current()

    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    local cursor = vim.api.nvim_win_get_cursor(0)
    local current_infoview = infoview.get_current_infoview()

    current_infoview:open()
    assert.windows.are(lean_window.id, current_infoview.window)

    -- Cursor did not move
    assert.current_window.is(lean_window)
    assert.current_cursor.is(cursor)

    -- Infoview is positioned at the top
    assert.current_cursor.is { 1, 0, window = current_infoview.window }
  end)

  it('remains open on editing a new Lean file', function()
    local windows = vim.api.nvim_tabpage_list_wins(0)
    assert.is.equal(#windows, 2) -- +1 above
    assert.is.truthy(vim.tbl_contains(windows, infoview.get_current_infoview().window))
    vim.cmd.edit(fixtures.project.some_existing_file)
    assert.windows.are(windows)
  end)

  it('remains open on splitting the current window', function()
    local windows = vim.api.nvim_tabpage_list_wins(0)
    assert.is.equal(2, #windows)
    assert.is.truthy(vim.tbl_contains(windows, infoview.get_current_infoview().window))

    vim.cmd.split()
    table.insert(windows, vim.api.nvim_get_current_win())
    assert.windows.are(windows)

    vim.cmd.edit { fixtures.project.some_nested_existing_file, bang = true }
    assert.windows.are(windows)

    vim.cmd.quit()
    table.remove(windows, #windows) -- the second Lean source window
    assert.windows.are(windows)
  end)

  it('is fixed width', function()
    local windows = vim.api.nvim_tabpage_list_wins(0)
    assert.is.equal(#windows, 2)
    assert.is.truthy(vim.wo[infoview.get_current_infoview().window].winfixwidth)
    assert.is.falsy(vim.wo[lean_window.id].winfixwidth)
  end)

  it('is unlisted', function()
    local current_infoview = infoview.get_current_infoview()
    local bufnr = vim.api.nvim_win_get_buf(current_infoview.window)
    assert.is_false(vim.bo[bufnr].buflisted)
  end)

  it('closes via its Lua API and stays closed', function()
    infoview.get_current_infoview():close()
    assert.windows.are(lean_window.id)

    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    assert.windows.are(lean_window.id)

    vim.cmd.split()
    assert.windows.are(lean_window.id, vim.api.nvim_get_current_win())

    vim.cmd.close()
    assert.windows.are(lean_window.id)
  end)

  it('reopens via its Lua API', function()
    local current_infoview = infoview.get_current_infoview()

    current_infoview:close()
    assert.windows.are(lean_window.id)

    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    assert.windows.are(lean_window.id)

    current_infoview:open()
    assert.windows.are(lean_window.id, current_infoview.window)
  end)

  it('quits via command mode and stays closed until reopened', function()
    local current_infoview = infoview.get_current_infoview()
    assert.windows.are(lean_window.id, current_infoview.window)

    -- Close via :quit
    current_infoview:enter()
    vim.cmd.quit()
    assert.windows.are(lean_window.id)

    -- Does not reopen when editing or splitting new Lean windows
    vim.cmd.edit { fixtures.project.some_nested_existing_file, bang = true }
    assert.windows.are(lean_window.id)

    local split = lean_window:split { enter = true }
    assert.windows.are(lean_window.id, split.id)

    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    assert.windows.are(lean_window.id, split.id)

    split:close()
    assert.windows.are(lean_window.id)

    -- Reopen, then close via :close, and assert the same as above
    current_infoview:open()
    assert.windows.are(lean_window.id, current_infoview.window)

    current_infoview:enter()
    vim.cmd.close()
    assert.windows.are(lean_window.id)

    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    assert.windows.are(lean_window.id)
  end)

  describe('in multiple tabs', function()
    it('closes independently', function()
      local tab1_infoview = infoview.get_current_infoview()
      tab1_infoview:open()
      assert.windows.are(lean_window.id, tab1_infoview.window)

      vim.cmd.tabnew()
      local tab2 = vim.api.nvim_get_current_tabpage()
      local tab2_window = Window:current()
      assert.windows.are(tab2_window.id)

      vim.cmd.edit { fixtures.project.some_existing_file, bang = true }

      local tab2_infoview = infoview.get_current_infoview()
      assert.are_not.same(tab1_infoview, tab2_infoview)

      assert.windows.are(tab2_window.id, tab2_infoview.window)

      -- Close the second tab infoview, and assert the first one stayed open
      tab2_infoview:close()
      assert.windows.are(tab2_window.id)

      vim.cmd.tabprevious()
      assert.windows.are(lean_window.id, tab1_infoview.window)

      -- And assert the same via command mode just in case
      vim.cmd.tabnext()
      tab2_infoview:open()
      tab2_infoview:enter()
      vim.cmd.quit()

      vim.cmd.tabprevious()
      assert.windows.are(lean_window.id, tab1_infoview.window)

      vim.cmd.tabclose(tab2)
    end)

    it('closes independently via :quit', function()
      vim.cmd.tabedit(fixtures.project.some_existing_file)
      local tab2_windows = vim.api.nvim_tabpage_list_wins(0)
      assert.is.equal(2, #tab2_windows)

      vim.cmd.tabedit(fixtures.project.some_existing_file)
      assert.is.equal(2, #vim.api.nvim_tabpage_list_wins(0))

      -- Close the two tab 3 windows
      vim.cmd.quit()
      vim.cmd.quit()

      assert.is.equal(2, #vim.api.nvim_tabpage_list_wins(0))

      vim.cmd.tabclose()
    end)
  end)

  it('closes when its buffer is deleted and stays closed until reopened', function()
    local current_infoview = infoview.get_current_infoview()
    current_infoview:open()
    assert.windows.are(lean_window.id, current_infoview.window)

    vim.cmd.split 'third_non_lean_window'
    local non_lean_window = Window:current()

    -- Close the Lean source window via :bd
    lean_window:call(vim.cmd.bdelete)
    assert.windows.are(current_infoview.window, non_lean_window.id)

    -- Close the infoview window now too
    vim.api.nvim_win_close(current_infoview.window, true)
    assert.windows.are(non_lean_window.id)

    current_infoview:open()
    assert.windows.are(non_lean_window.id, current_infoview.window)

    -- Cleanup by now opening a Lean file in the window we opened, so future
    -- tests can use it (grr, global state...).
    non_lean_window:make_current()
    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    lean_window = non_lean_window
  end)

  it('can be reopened when an infoview buffer was reused for editing a file', function()
    vim.cmd.tabnew()
    local transient_window = Window:current()

    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    local initial_infoview = infoview.get_current_infoview()
    local initial_infoview_window = Window:from_id(initial_infoview.window)
    assert.windows.are(transient_window.id, initial_infoview_window.id)

    vim.cmd.quit()
    assert.current_window.is(initial_infoview_window)
    vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
    assert.windows.are(initial_infoview_window.id)

    local second_infoview = infoview.get_current_infoview()
    assert.is_not.equal(second_infoview.window, initial_infoview_window.id)
    second_infoview:open()
    assert.windows.are(initial_infoview_window.id, second_infoview.window)

    vim.cmd.tabclose()
  end)

  it(
    'can be reopened when the last remaining infoview buffer was reused for editing a file',
    function()
      assert.is.equal(1, #vim.api.nvim_list_tabpages())
      local initial_infoview = infoview.get_current_infoview()
      local initial_infoview_window = initial_infoview.window
      assert.windows.are(lean_window.id, initial_infoview_window)
      lean_window:close()
      vim.cmd.edit { fixtures.project.some_existing_file, bang = true }
      assert.windows.are(initial_infoview_window)

      local second_infoview = infoview.get_current_infoview()
      assert.is_not.equal(second_infoview.window, initial_infoview_window)
      second_infoview:open()
      assert.windows.are(initial_infoview_window, second_infoview.window)
    end
  )
end)
