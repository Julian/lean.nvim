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


require('lean').setup{}

describe('infoview content (auto-)update', function()

  local lean_window

  it("shows the initial cursor location's infoview", function()
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('edit! ' .. fixtures.lean_project.path .. '/Test/Squares.lean')
    lean_window = vim.api.nvim_get_current_win()
    -- In theory we don't care where we are, but the right answer changes
    assert.are.same(vim.api.nvim_win_get_cursor(0), {1, 0})

    helpers.wait_for_infoview_contents('\n1')
    -- FIXME: Trailing extra newline.
    assert.infoview_contents.are[[
      ▶ 1:1-1:6: information:
      1

    ]]
  end)

  it('updates when the cursor moves', function()
    assert.are_not.same(vim.api.nvim_win_get_cursor(0), {3, 0})

    helpers.move_cursor{ to = {3, 0} }
    helpers.wait_for_infoview_contents('\n9')
    -- FIXME: Trailing extra newline.
    assert.infoview_contents.are[[
      ▶ 3:1-3:6: information:
      9.000000

    ]]
  end)

  it('is shared between separate windows', function()
    assert.is.equal(lean_window, vim.api.nvim_get_current_win())

    vim.cmd('split')
    local second_window = vim.api.nvim_get_current_win()
    assert.are.same(vim.api.nvim_win_get_cursor(0), {3, 0})
    helpers.wait_for_infoview_contents('\n9')
    assert.infoview_contents.are[[
      ▶ 3:1-3:6: information:
      9.000000

    ]]

    helpers.move_cursor{ to = {1, 0} }
    helpers.wait_for_infoview_contents('\n1')
    assert.infoview_contents.are[[
      ▶ 1:1-1:6: information:
      1

    ]]

    -- Now switch back to the other window and...
    vim.cmd[[wincmd p]]
    helpers.wait_for_infoview_contents('\n9')
    assert.infoview_contents.are[[
      ▶ 3:1-3:6: information:
      9.000000

    ]]

    vim.api.nvim_win_close(second_window, false)
  end)

  it('does not update for non-Lean buffers', function()
    assert.is.equal(lean_window, vim.api.nvim_get_current_win())

    local original_lines = infoview.get_current_infoview():get_lines()
    vim.cmd('split some_non_lean_file.tmp')
    helpers.insert('some stuff')
    assert.are.same(original_lines, infoview.get_current_infoview():get_lines())

    vim.cmd('close!')
  end)

  it('does not error while closed and continues updating when reopened', function()
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
    helpers.wait_for_infoview_contents('\n1')
    assert.infoview_contents.are[[
      ▶ 1:1-1:6: information:
      1

    ]]

    helpers.move_cursor{ to = {3, 0} }
    helpers.wait_for_infoview_contents('\n9')
    assert.infoview_contents.are[[
      ▶ 3:1-3:6: information:
      9.000000

    ]]
  end)

  it('does not have line contents while closed', function()
    assert.are.same_elements(
      { lean_window, infoview.get_current_infoview().window },
      vim.api.nvim_tabpage_list_wins(0)
    )
    local current_infoview = infoview.get_current_infoview()
    current_infoview:close()
    assert.has.errors(
      function() current_infoview:get_lines() end,
      "infoview is not open"
    )

    -- But succeeds again when re-opened
    current_infoview:open()
    assert.has.no.errors(function() current_infoview:get_lines() end)
  end)

  describe('in multiple tabs', function()
    it('updates separate infoviews independently', function()
      local tab1_infoview = infoview.get_current_infoview()
      assert.same.elements(
        { lean_window, tab1_infoview.window },
        vim.api.nvim_tabpage_list_wins(0)
      )

      helpers.move_cursor{ to = {1, 0} }
      helpers.wait_for_infoview_contents('\n1')
      assert.infoview_contents.are[[
        ▶ 1:1-1:6: information:
        1

      ]]

      vim.cmd('tabnew' .. fixtures.lean_project.path .. '/Test/Squares.lean')
      helpers.move_cursor{ to = {3, 0} }
      helpers.wait_for_infoview_contents('\n9')
      assert.infoview_contents.are[[
        ▶ 3:1-3:6: information:
        9.000000

      ]]

      -- But the first tab's contents are unchanged even without re-entering.
      assert.infoview_contents.are{
        [[
          ▶ 1:1-1:6: information:
          1

        ]],
        infoview = tab1_infoview
      }
    end)

    it('updates separate infoviews independently when one is closed', function()
      local tab2 = vim.api.nvim_get_current_tabpage()
      assert.is_not.equal(vim.api.nvim_win_get_tabpage(lean_window), tab2)

      infoview.get_current_infoview():close()
      vim.cmd('tabprevious')

      helpers.move_cursor{ to = {3, 0} }
      helpers.wait_for_infoview_contents('\n9')
      assert.infoview_contents.are[[
        ▶ 3:1-3:6: information:
        9.000000

      ]]

      helpers.move_cursor{ to = {1, 0} }
      helpers.wait_for_infoview_contents('\n1')
      assert.infoview_contents.are[[
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

  describe('components', function()
    describe('lean 4', function()

      vim.cmd('edit! ' .. fixtures.lean_project.path .. '/Test.lean')

      it('shows a term goal', function()
        helpers.move_cursor{ to = {3, 27} }
        helpers.wait_for_infoview_contents('expected type')
        assert.infoview_contents.are[[
          ▶ expected type (3:28-3:36)
          ⊢ Nat
        ]]
      end)

      it('shows a tactic goal', function()
        helpers.move_cursor{ to = {6, 0} }
        helpers.wait_for_infoview_contents('1 goal')
        assert.infoview_contents.are[[
          ▶ 1 goal
          p q : Prop
          ⊢ p ∨ q → q ∨ p
        ]]
      end)

      it('shows mixed goals', function()
        helpers.move_cursor{ to = {7, 8} }
        helpers.wait_for_infoview_contents('7:9')
        assert.infoview_contents.are[[
          ▶ 1 goal
          p q : Prop
          h : p ∨ q
          ⊢ q ∨ p

          ▶ expected type (7:9-7:10)
          p q : Prop
          h : p ∨ q
          ⊢ p ∨ q
        ]]
      end)

      it('shows multiple goals', function()
        helpers.move_cursor{ to = {17, 2} }
        helpers.wait_for_infoview_contents('goals')
        assert.infoview_contents.are[[
          ▶ 2 goals
          case zero
          ⊢ Nat.zero = Nat.zero

          case succ
          n✝ : Nat
          ⊢ Nat.succ n✝ = Nat.succ n✝
        ]]
      end)

      it('properly handles multibyte characters', function()
        helpers.move_cursor{ to = {20, 62} }
        helpers.wait_for_infoview_contents('expected type')
        assert.infoview_contents.are[[
          ▶ expected type (20:54-20:57)
          𝔽 : Type
          ⊢ 𝔽 = 𝔽
        ]]

        helpers.move_cursor{ to = {20, 58} }
        helpers.wait_for_infoview_contents('^$')
        assert.infoview_contents.are[[
        ]]

        helpers.move_cursor{ to = {20, 60} }
        helpers.wait_for_infoview_contents('expected type')
        assert.infoview_contents.are[[
          ▶ expected type (20:54-20:57)
          𝔽 : Type
          ⊢ 𝔽 = 𝔽
       ]]
      end)

      it('autoupdates when contents are modified without the cursor moving', function()
        --- FIXME: This test is meant to ensure that we re-send requests on ContentModified LSP
        ---        errors, but it doesn't seem to do that (it doesn't seem to do particularly that
        ---        even before being refactored though, as it passes with or without the relevant
        ---        lines in infoview.lua)
        helpers.move_cursor{ to = {23, 1} }
        helpers.wait_for_infoview_contents('37')
        assert.infoview_contents.are[[
          ▶ 1 goal
          ⊢ 37 = 37
        ]]
        vim.api.nvim_buf_set_lines(0, 21, 22, true, {"def will_be_modified : 2 = 2 := by"})
        helpers.wait_for_infoview_contents('2')
        assert.infoview_contents.are[[
          ▶ 1 goal
          ⊢ 2 = 2
        ]]
      end)
    end)

    describe('lean 3', function()

      vim.cmd('edit! ' .. fixtures.lean3_project.path .. '/src/bar/baz.lean')

      it('shows a term goal', function()
        helpers.move_cursor{ to = {3, 27} }
        -- FIXME: There is a race condition here which likely is an actual
        --        (minor) bug. In CI, which is slower than locally, the below
        --        will often flakily fail without the pcall-and-retry. This
        --        likely is the update starting too early, and should be
        --        detected (and delayed) in the real code, but for now it's
        --        just hacked around here.
        local succeeded, _ = pcall(helpers.wait_for_infoview_contents, 'expected type')
        if not succeeded then
          -- move away and back to retry
          helpers.move_cursor{ to = {2, 0} }
          helpers.move_cursor{ to = {3, 27} }
          helpers.wait_for_infoview_contents('expected type')
        end

        assert.infoview_contents.are[[
          ▶ expected type:
          ⊢ ℕ
        ]]
      end)

      it('shows a tactic goal', function()
        helpers.move_cursor{ to = {6, 0} }
        helpers.wait_for_infoview_contents('1 goal')
        -- FIXME: extra internal newline compared to Lean 4
        assert.infoview_contents.are[[
          filter: no filter
          ▶ 1 goal
          p q : Prop
          ⊢ p ∨ q → q ∨ p
        ]]
      end)

      it('shows multiple goals', function()
        helpers.move_cursor{ to = {20, 2} }
        helpers.wait_for_infoview_contents('goals')
        assert.infoview_contents.are[[
          filter: no filter
          ▶ 2 goals
          case nat.zero
          ⊢ 0 = 0

          case nat.succ
          n : ℕ
          ⊢ n.succ = n.succ
        ]]
      end)

      if vim.version().major >= 1 or vim.version().minor >= 6 then
        it('properly handles multibyte characters', function()
          helpers.move_cursor{ to = {24, 61} }
          helpers.wait_for_infoview_contents('expected type')
          assert.infoview_contents.are[[
            ▶ expected type:
            𝔽 : Type
            ⊢ 𝔽 = 𝔽
          ]]

          helpers.move_cursor{ to = {24, 58} }
          helpers.wait_for_infoview_contents('^$')
          assert.infoview_contents.are[[
          ]]

          helpers.move_cursor{ to = {24, 60} }
          helpers.wait_for_infoview_contents('expected type')
          assert.infoview_contents.are[[
            ▶ expected type:
            𝔽 : Type
            ⊢ 𝔽 = 𝔽
          ]]
        end)
      end
    end)
  end)

  describe('processing message', helpers.clean_buffer('lean', '#eval IO.sleep 5000', function()
    it('is shown while a file is processing', function()
      local uri = vim.uri_from_fname(vim.api.nvim_buf_get_name(0))
      local result = vim.wait(5000, function() return require('lean.progress').is_processing(uri) end)
      assert.message('file was never processing').is_true(result)
      assert.infoview_contents.are('Processing file...')
    end)
  end))
end)
