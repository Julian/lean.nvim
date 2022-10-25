---@brief [[
--- Tests for the automatic updating of infoview contents.
---
--- When debugging tests here, if you're confused about something not updating,
--- sprinkle print debugging around `infoview.Pin:__update`. Don't forget some
--- functions are run asynchronously, so if you don't see an update, it may be
--- because a test has finished before the promise fires, which usually means
--- the test needs to wait for an update (which `assert.infoview_contents`
--- does automatically, so use it).
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

require('lean').setup{ infoview = { use_widgets = false } }

describe('infoview content (auto-)update', function()

  local lean_window

  it("shows the initial cursor location's infoview", function()
    assert.is.equal(1, #vim.api.nvim_tabpage_list_wins(0))

    vim.cmd('edit! ' .. fixtures.lean_project.path .. '/Test/Squares.lean')
    lean_window = vim.api.nvim_get_current_win()
    -- In theory we don't care where we are, but the right answer changes
    assert.are.same(vim.api.nvim_win_get_cursor(0), {1, 0})

    -- FIXME: Trailing extra newline.
    assert.infoview_contents.are[[
      ▶ 1:1-1:6: information:
      1

    ]]
  end)

  it('updates when the cursor moves', function()
    assert.are_not.same(vim.api.nvim_win_get_cursor(0), {3, 0})

    helpers.move_cursor{ to = {3, 0} }
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
    assert.infoview_contents.are[[
      ▶ 3:1-3:6: information:
      9.000000

    ]]

    helpers.move_cursor{ to = {1, 0} }
    assert.infoview_contents.are[[
      ▶ 1:1-1:6: information:
      1

    ]]

    -- Now switch back to the other window and...
    vim.cmd[[wincmd p]]
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
    assert.windows.are(lean_window, infoview.get_current_infoview().window)
    assert.are_not.same(vim.api.nvim_win_get_cursor(0), {1, 0})

    infoview.close()

    -- Move around a bit.
    helpers.move_cursor{ to = {1, 0} }
    helpers.move_cursor{ to = {2, 0} }
    helpers.move_cursor{ to = {1, 0} }

    infoview.open()
    assert.infoview_contents.are[[
      ▶ 1:1-1:6: information:
      1

    ]]

    helpers.move_cursor{ to = {3, 0} }
    assert.infoview_contents.are[[
      ▶ 3:1-3:6: information:
      9.000000

    ]]
  end)

  it('does not have line contents while closed', function()
    assert.windows.are(lean_window, infoview.get_current_infoview().window)
    infoview.close()
    assert.has.errors(
      function() infoview.get_current_infoview():get_lines() end,
      "infoview is not open"
    )

    -- But succeeds again when re-opened
    infoview.open()
    assert.has.no.errors(function() infoview.get_current_infoview():get_lines() end)
  end)

  describe('in multiple tabs', function()
    it('updates separate infoviews independently', function()
      local tab1_infoview = infoview.get_current_infoview()
      assert.windows.are(lean_window, tab1_infoview.window)

      helpers.move_cursor{ to = {1, 0} }
      assert.infoview_contents.are[[
        ▶ 1:1-1:6: information:
        1

      ]]

      vim.cmd('tabnew' .. fixtures.lean_project.path .. '/Test/Squares.lean')
      helpers.move_cursor{ to = {3, 0} }
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

      infoview.close()
      vim.cmd('tabprevious')

      helpers.move_cursor{ to = {3, 0} }
      assert.infoview_contents.are[[
        ▶ 3:1-3:6: information:
        9.000000

      ]]

      helpers.move_cursor{ to = {1, 0} }
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
        assert.infoview_contents.are[[
          ▶ expected type (3:28-3:36)
          ⊢ Nat
        ]]
      end)

      it('shows a tactic goal', function()
        helpers.move_cursor{ to = {6, 0} }
        assert.infoview_contents.are[[
          ▶ 1 goal
          p q : Prop
          ⊢ p ∨ q → q ∨ p
        ]]
      end)

      it('shows mixed goals', function()
        helpers.move_cursor{ to = {9, 11} }
        assert.infoview_contents.are[[
          ▶ 1 goal
          case inl.h
          p q : Prop
          h1 : p
          ⊢ p

          ▶ expected type (9:11-9:17)
          p q : Prop
          h1 : p
          ⊢ ∀ {a b : Prop}, b → a ∨ b
        ]]
      end)

      it('shows multiple goals', function()
        helpers.move_cursor{ to = {16, 2} }
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
        assert.infoview_contents.are[[
          ▶ expected type (20:54-20:57)
          𝔽 : Type
          ⊢ 𝔽 = 𝔽
        ]]

        helpers.move_cursor{ to = {20, 58} }
        assert.infoview_contents.are[[
        ]]

        helpers.move_cursor{ to = {20, 60} }
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
        assert.infoview_contents.are[[
          ▶ 1 goal
          ⊢ 37 = 37
        ]]
        vim.api.nvim_buf_set_lines(0, 21, 22, true, {"def will_be_modified : 2 = 2 := by"})
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

        assert.infoview_contents.are[[
          ▶ 1 goal
          ⊢ ℕ
        ]]
      end)

      it('shows a tactic goal', function()
        helpers.move_cursor{ to = {6, 0} }
        assert.infoview_contents.are[[
          ▶ 1 goal
          p q : Prop
          ⊢ p ∨ q → q ∨ p
        ]]
      end)

      it('shows multiple goals', function()
        helpers.move_cursor{ to = {20, 2} }
        assert.infoview_contents.are[[
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
          assert.infoview_contents.are[[
            ▶ 1 goal
            𝔽 : Type
            ⊢ 𝔽 = 𝔽
          ]]

          -- NOTE: spurious (checks for a zero-length Lean 3 response,
          -- which could have multiple causes)
          helpers.move_cursor{ to = {24, 58} }
          helpers.wait_for_loading_pins()
          assert.infoview_contents_nowait.are[[
          ]]

          helpers.move_cursor{ to = {24, 60} }
          assert.infoview_contents.are[[
            ▶ 1 goal
            𝔽 : Type
            ⊢ 𝔽 = 𝔽
          ]]
        end)
      end
    end)
  end)

  for ft, goal in pairs{ lean = '⊢ true = true', lean3 = '⊢ true' } do
    describe(ft .. ' cursor position', helpers.clean_buffer(ft, '', function()
      it('is set to the goal line', function()
        local lines = { 'example ' }
        for i=1, 100 do
          table.insert(lines, "(h" .. i .. " : " .. i .. " = " .. i .. ")")
        end
        table.insert(lines, ': true :=')
        table.insert(lines, 'sorry')

        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        helpers.move_cursor{ to = { #lines, 1 } }
        helpers.wait_for_loading_pins()

        vim.api.nvim_set_current_win(infoview.get_current_infoview().window)

        assert.are.equal(vim.api.nvim_get_current_line(), goal)
        assert.are.equal(vim.api.nvim_win_get_cursor(0)[2], #'⊢ ')
      end)
    end))
  end

  describe('processing message', helpers.clean_buffer('lean', '#eval IO.sleep 5000', function()
    it('is shown while a file is processing', function()
      local uri = vim.uri_from_fname(vim.api.nvim_buf_get_name(0))
      local result = vim.wait(15000, function() return require('lean.progress').is_processing(uri) end)
      assert.message('file was never processing').is_true(result)
      assert.infoview_contents_nowait.are('Processing file...')
    end)
  end))
end)
