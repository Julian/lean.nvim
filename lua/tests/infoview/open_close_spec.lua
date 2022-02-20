---@brief [[
--- Tests for the opening and closing of infoviews via command mode, their Lua
--- API, or combinations of the two.
---@brief ]]

require('tests.helpers')
local infoview = require('lean.infoview')
local fixtures = require('tests.fixtures')

require('lean').setup{}

describe('infoview open/close', function()

  local lean_window

  it('opens', function(_)
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    lean_window = vim.api.nvim_get_current_win()

    vim.cmd('edit! ' .. fixtures.lean_project.some_existing_file)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local current_infoview = infoview.get_current_infoview()

    current_infoview:open()
    assert.are.same_elements(
      { lean_window, current_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    -- Cursor did not move
    assert.is.equal(vim.api.nvim_get_current_win(), lean_window)
    assert.are.same(vim.api.nvim_win_get_cursor(0), cursor)

    -- Infoview is positioned at the top
    assert.are.same(
      {1, 0},
      vim.api.nvim_win_get_cursor(current_infoview.window)
    )
  end)

  it('remains open on editing a new Lean file', function(_)
    local windows = vim.api.nvim_tabpage_list_wins(0)
    assert.is.equal(#windows, 2)  -- +1 above
    assert.is.truthy(
      vim.tbl_contains(windows, infoview.get_current_infoview().window)
    )
    vim.cmd('edit ' .. fixtures.lean_project.some_existing_file)
    assert.are.same(windows, vim.api.nvim_tabpage_list_wins(0))
  end)

  it('remains open on splitting the current window', function(_)
    local windows = vim.api.nvim_tabpage_list_wins(0)
    assert.is.equal(2, #windows)  -- +1 above
    assert.is.truthy(
      vim.tbl_contains(windows, infoview.get_current_infoview().window)
    )

    vim.cmd('split')
    table.insert(windows, vim.api.nvim_get_current_win())
    assert.are.same_elements(windows, vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('edit! ' .. fixtures.lean_project.some_nested_existing_file)
    assert.are.same_elements(windows, vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('quit')
    table.remove(windows, #windows)  -- the second Lean source window
    assert.are.same_elements(windows, vim.api.nvim_tabpage_list_wins(0))
  end)

  it('closes via its Lua API and stays closed', function(_)
    infoview.get_current_infoview():close()
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('edit! ' .. fixtures.lean_project.some_existing_file)
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('split')
    assert.are.same_elements(
      { lean_window, vim.api.nvim_get_current_win() },
      vim.api.nvim_tabpage_list_wins(0)
    )

    vim.cmd('close')
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))
  end)

  it('reopens via its Lua API', function(_)
    local current_infoview = infoview.get_current_infoview()

    current_infoview:close()
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('edit! ' .. fixtures.lean_project.some_existing_file)
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))

    current_infoview:open()
    assert.same.elements(
      { lean_window, current_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )
  end)

  it('quits via command mode and stays closed until reopened', function(_)
    local current_infoview = infoview.get_current_infoview()
    assert.same.elements(
      { lean_window, current_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    -- Close via :quit
    vim.api.nvim_set_current_win(current_infoview.window)
    vim.cmd('quit')
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))

    -- Does not reopen when editing or splitting new Lean windows
    vim.cmd('edit! ' .. fixtures.lean_project.some_nested_existing_file)
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('split')
    local split = vim.api.nvim_get_current_win()
    assert.are.same_elements(
      { lean_window, split },
      vim.api.nvim_tabpage_list_wins(0)
    )

    vim.cmd('edit! ' .. fixtures.lean_project.some_existing_file)
    assert.are.same_elements(
      { lean_window, split },
      vim.api.nvim_tabpage_list_wins(0)
    )

    vim.cmd('close')
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))

    -- Reopen, then close via :close, and assert the same as above
    current_infoview:open()
    assert.same.elements(
      { lean_window, current_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    vim.api.nvim_set_current_win(current_infoview.window)
    vim.cmd('close')
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('edit! ' .. fixtures.lean_project.some_existing_file)
    assert.are.same({ lean_window }, vim.api.nvim_tabpage_list_wins(0))
  end)

  describe('in multiple tabs', function()
    it('closes independently', function(_)
      local tab1_infoview = infoview.get_current_infoview()
      assert.same.elements(
        { lean_window, tab1_infoview.window },
        vim.api.nvim_tabpage_list_wins(0)
      )

      vim.cmd('tabnew')
      local tab2 = vim.api.nvim_get_current_tabpage()
      local tab2_window = vim.api.nvim_get_current_win()
      assert.are.same({ tab2_window }, vim.api.nvim_tabpage_list_wins(0))

      vim.cmd('edit! ' .. fixtures.lean_project.some_existing_file)

      local tab2_infoview = infoview.get_current_infoview()
      assert.are_not.same(tab1_infoview, tab2_infoview)

      assert.same.elements(
        { tab2_window, tab2_infoview.window },
        vim.api.nvim_tabpage_list_wins(0)
      )

      -- Close the second tab infoview, and assert the first one stayed open
      tab2_infoview:close()
      assert.are.same({ tab2_window }, vim.api.nvim_tabpage_list_wins(0))

      vim.cmd('tabprevious')
      assert.same.elements(
        { lean_window, tab1_infoview.window },
        vim.api.nvim_tabpage_list_wins(0)
      )

      -- And assert the same via command mode just in case
      vim.cmd('tabnext')
      tab2_infoview:open()
      vim.api.nvim_set_current_win(tab2_infoview.window)
      vim.cmd('quit')

      vim.cmd('tabprevious')
      assert.same.elements(
        { lean_window, tab1_infoview.window },
        vim.api.nvim_tabpage_list_wins(0)
      )

      vim.cmd('tabclose ' .. tab2)
    end)

    it('closes independently via :quit', function(_)
      vim.cmd('tabedit ' .. fixtures.lean_project.some_existing_file)
      local tab2_windows = vim.api.nvim_tabpage_list_wins(0)
      assert.is.equal(2, #tab2_windows)

      vim.cmd('tabedit ' .. fixtures.lean_project.some_existing_file)
      assert.is.equal(2, #vim.api.nvim_tabpage_list_wins(0))

      -- Close the two tab 3 windows
      vim.cmd('quit')
      vim.cmd('quit')

      assert.is.equal(2, #vim.api.nvim_tabpage_list_wins(0))

      vim.cmd('tabclose')
    end)
  end)

  it('closes when its buffer is deleted and stays closed until reopened', function(_)
    local current_infoview = infoview.get_current_infoview()
    current_infoview:open()
    assert.same.elements(
      { lean_window, current_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    vim.cmd('split third_non_lean_window')
    local non_lean_window = vim.api.nvim_get_current_win()

    -- Close the Lean source window via :bd
    vim.fn.win_execute(lean_window, 'bdelete')
    assert.are.same_elements(
      { current_infoview.window, non_lean_window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    -- Close the infoview window now too
    vim.api.nvim_win_close(current_infoview.window, true)
    assert.are.same({ non_lean_window }, vim.api.nvim_tabpage_list_wins(0))

    current_infoview:open()
    assert.same.elements(
      { non_lean_window, current_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    -- Cleanup by now opening a Lean file in the window we opened, so future
    -- tests can use it (grr, global state...).
    vim.api.nvim_set_current_win(non_lean_window)
    vim.cmd('edit! ' .. fixtures.lean_project.some_existing_file)
    lean_window = non_lean_window
  end)

  it('can be reopened when an infoview buffer was reused for editing a file', function()
    vim.cmd('tabnew')
    local transient_window = vim.api.nvim_get_current_win()

    vim.cmd('edit! ' .. fixtures.lean_project.some_existing_file)
    local initial_infoview = infoview.get_current_infoview()
    local initial_infoview_window = initial_infoview.window
    assert.are.same_elements(
      { transient_window, initial_infoview_window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    vim.cmd(':quit')
    assert.is.equal(initial_infoview_window, vim.api.nvim_get_current_win())
    vim.cmd('edit! ' .. fixtures.lean_project.some_existing_file)
    assert.are.same({ initial_infoview_window }, vim.api.nvim_tabpage_list_wins(0))

    local second_infoview = infoview.get_current_infoview()
    assert.is_not.equal(second_infoview.window, initial_infoview_window)
    second_infoview:open()
    assert.are.same_elements(
      { initial_infoview_window, second_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )

    vim.cmd('tabclose')
  end)

  it('can be reopened when the last remaining infoview buffer was reused for editing a file', function()
    assert.is.equal(1, #vim.api.nvim_list_tabpages())
    local initial_infoview = infoview.get_current_infoview()
    local initial_infoview_window = initial_infoview.window
    assert.same.elements(
      { lean_window, initial_infoview_window },
      vim.api.nvim_tabpage_list_wins(0)
    )
    vim.api.nvim_win_close(lean_window, false)
    vim.cmd('edit! ' .. fixtures.lean_project.some_existing_file)
    assert.are.same({ initial_infoview_window }, vim.api.nvim_tabpage_list_wins(0))

    local second_infoview = infoview.get_current_infoview()
    assert.is_not.equal(second_infoview.window, initial_infoview_window)
    second_infoview:open()
    assert.are.same_elements(
      { initial_infoview_window, second_infoview.window },
      vim.api.nvim_tabpage_list_wins(0)
    )
  end)
end)
