---@brief [[
--- Tests for tooltips (rendered inside infoviews).
---
--- Really this should combine with the user widget tests (which it preceeds).
---@brief ]]

local Tab = require 'std.nvim.tab'
local Window = require 'std.nvim.window'

local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'

require('lean').setup {}

describe(
  'infoview widgets',
  helpers.clean_buffer('#check Nat', function()
    local lean_window = Window:current()
    local current_infoview = infoview.get_current_infoview()

    it('shows widget tooltips', function()
      helpers.move_cursor { to = { 1, 8 } }
      assert.infoview_contents.are [[
        ▼ expected type (1:8-1:11)
        ⊢ Type

        ▼ 1:1-1:7: information:
        Nat : Type
      ]]

      current_infoview:enter()
      helpers.move_cursor { to = { 2, 5 } } -- `Type`

      local known_windows = { lean_window, current_infoview.window }
      assert.windows.are(known_windows)

      helpers.feed '<CR>'
      local tooltip = helpers.wait_for_new_window(known_windows)
      assert.contents.are {
        'Type : Type 1\n\nA type universe. `Type ≡ Type 0`, `Type u ≡ Sort (u + 1)`. ',
        buffer = tooltip:buffer(),
      }

      -- Close the tooltip.
      helpers.feed '<Esc>'
      assert.windows.are(known_windows)
    end)

    it('dismisses nested tooltips', function()
      helpers.move_cursor { to = { 1, 8 } }
      assert.infoview_contents.are [[
        ▼ expected type (1:8-1:11)
        ⊢ Type

        ▼ 1:1-1:7: information:
        Nat : Type
      ]]

      current_infoview:enter()
      helpers.search 'Type'

      local known_windows = { lean_window, current_infoview.window }
      assert.windows.are(known_windows)

      helpers.feed '<CR>'
      local tooltip = helpers.wait_for_new_window(known_windows)
      assert.current_window.is(current_infoview.window)

      helpers.feed '<Tab>'
      assert.current_window.is(tooltip)

      local with_tooltip = vim.list_extend(vim.deepcopy(known_windows), { tooltip })

      helpers.search 'Type 1'
      helpers.feed '<CR>'

      helpers.wait_for_new_window(with_tooltip)

      helpers.feed '<Esc>'

      -- All tooltips are gone.
      assert.windows.are(known_windows)
    end)

    it('does not abandon tooltips when the infoview is closed', function()
      vim.cmd.tabnew '#'
      local tab2_window = Window:current()
      local tab2_infoview = infoview.get_current_infoview()
      helpers.move_cursor { to = { 1, 9 } }
      helpers.wait_for_loading_pins()
      tab2_infoview:enter()
      helpers.move_cursor { to = { 2, 5 } } -- `Type`
      helpers.feed '<CR>'

      helpers.wait_for_new_window { tab2_window, tab2_infoview.window }
      assert.is.equal(3, #Tab:current():windows())

      -- Now close the infoview entirely, and the tooltip should close too.
      tab2_infoview:close()

      assert.is.equal(1, #Tab:current():windows())
      tab2_window:close()

      assert.is.equal(1, #Tab:all())
    end)

    it('does not abandon tooltips when windows are closed', function()
      vim.cmd.tabnew '#'
      local tab2_window = Window:current()
      local tab2_infoview = infoview.get_current_infoview()
      helpers.move_cursor { to = { 1, 8 } }
      helpers.wait_for_loading_pins()
      tab2_infoview:enter()
      helpers.move_cursor { to = { 2, 5 } } -- `Type`
      helpers.feed '<CR>'

      helpers.wait_for_new_window { tab2_window, tab2_infoview.window }
      assert.is.equal(3, #Tab:current():windows())

      assert.is.equal(2, #Tab:all())

      -- Now close the other 2 windows, and the tooltip should close too.
      tab2_infoview.window:close()
      tab2_window:close()

      assert.is.equal(1, #Tab:all())
    end)
  end)
)

describe(
  'tactic mode',
  helpers.clean_buffer(
    [[
      example : Type := by
        sorry
    ]],
    function()
      local lean_window = Window:current()
      local current_infoview = infoview.get_current_infoview()

      it('shows widget tooltips', function()
        helpers.search 'sorry'
        assert.infoview_contents.are [[⊢ Type]]

        local known_windows = { lean_window, current_infoview.window }
        assert.windows.are(known_windows)

        current_infoview:enter()
        helpers.search 'ype' -- we're actually already on T
        helpers.feed '<CR>'
        local tooltip = helpers.wait_for_new_window(known_windows)
        assert.contents.are {
          'Type : Type 1\n\nA type universe. `Type ≡ Type 0`, `Type u ≡ Sort (u + 1)`. ',
          buffer = tooltip:buffer(),
        }

        -- Close the tooltip - this should work if clear_all event is preserved
        helpers.feed '<Esc>'
        assert.windows.are(known_windows)
      end)

      it('dismisses nested tooltips in simple tactic mode', function()
        assert.infoview_contents.are [[⊢ Type]]

        local known_windows = { lean_window, current_infoview.window }
        assert.windows.are(known_windows)

        current_infoview:enter()
        helpers.search 'pe' -- we're actually already on y
        helpers.feed '<CR>'
        local tooltip = helpers.wait_for_new_window(known_windows)
        assert.current_window.is(current_infoview.window)

        helpers.feed '<Tab>'
        assert.current_window.is(tooltip)

        local with_tooltip = vim.list_extend(vim.deepcopy(known_windows), { tooltip })

        helpers.search 'Type 1'
        helpers.feed '<CR>'
        helpers.wait_for_new_window(with_tooltip)

        helpers.feed '<Esc>'

        -- All tooltips are gone.
        assert.windows.are(known_windows)
      end)
    end
  )
)

describe(
  'contents',
  helpers.clean_buffer('#check Nat', function()
    it(
      'shows diagnostics',
      helpers.clean_buffer('example : 37 = 37 := by', function()
        helpers.move_cursor { to = { 1, 19 } }
        assert.infoview_contents.are [[
          ▼ 1:22-1:24: error:
          unsolved goals
          ⊢ 37 = 37
        ]]
      end)
    )
  end)
)

--- This checks that CR (aka click) on a symbol presents a proper tooltip.
describe(
  'infoview widgets tooltips for symbols',
  helpers.clean_buffer(
    [[example (h: ∃ a:Nat, a = 3) := by apply h]],
    function()
      local lean_window = Window:current()
      local current_infoview = infoview.get_current_infoview()

      it('shows widget tooltips', function()
        helpers.move_cursor { to = { 1, 9 } }
        assert.infoview_contents.are [[
        Goals accomplished 🎉

        ▼ expected type (1:10-1:11)
        ⊢ ∃ a, a = 3]]

        current_infoview:enter()
        helpers.move_cursor { to = { 4, 8 } } -- `a`

        local known_windows = { lean_window, current_infoview.window }
        assert.windows.are(known_windows)

        helpers.feed '<CR>'
        local tooltip = helpers.wait_for_new_window(known_windows)
        assert.contents.are {
          'a : Nat',
          buffer = tooltip:buffer(),
        }

        -- Close the tooltip.
        helpers.feed '<Esc>'
        assert.windows.are(known_windows)
      end)
    end
  )
)

--- Update client.request to handle designated methods by returning fake_result.
local function mock_client_request_rpc(client, orig_request_fn, fake_result)
  client.request = function(self, method, params, handler, ...)
    -- special case this method
    if params.method == "Lean.Widget.InteractiveDiagnostics.infoToInteractive" then
      vim.schedule(function()
        local ctx = {}
        handler(nil, fake_result, ctx)
      end)

      return true
    end

    -- forward all the others
    return orig_request_fn(self, method, params,
      function(err,res,ctx,cfg)
        -- wrap this to make a placeholder for extra test helpers
        return handler(err,res,ctx,cfg)
      end),
      ...
  end
end

--- Inject errors and check for proper handling.
describe(
  'infoview widgets tooltips for symbols, with errors',
  helpers.clean_buffer(
    [[example (h: ∃ a:Nat, a = 3) := by apply h]],
    function()
      local lean_window = Window:current()
      local current_infoview = infoview.get_current_infoview()

      local saved_request_fn
      local this_client

      -- Call within it() after current_infoview:enter(), to save the active
      -- client and its request method in this_client and saved_request_fn
      -- for mock_client_request_rpc to use.
      local function save_client_stuff()
        local bn = lean_window:bufnr()
        local clients = vim.lsp.get_clients({ bufnr = bn })
        if #clients == 0 then return end
        this_client = clients[1]
        saved_request_fn = this_client.request
      end

      after_each(function()
        if this_client and saved_request_fn then
          this_client.request = saved_request_fn
        end
      end)

      it('shows widget tooltips, missing type', function()
        helpers.move_cursor { to = { 1, 9 } }
        assert.infoview_contents.are [[
        Goals accomplished 🎉

        ▼ expected type (1:10-1:11)
        ⊢ ∃ a, a = 3]]

        current_infoview:enter()
        helpers.move_cursor { to = { 4, 8 } } -- `a`

        local known_windows = { lean_window, current_infoview.window }
        assert.windows.are(known_windows)

        save_client_stuff()
        local fake_result = {
          doc = vim.NIL,
          exprExplicit = { text = "a" },
          type = vim.NIL,
        }
        -- standard result:
        --  doc = vim.NIL,
        --  exprExplicit = { text = "a" },
        --  type = { tag = { { info = { p = "14" }, subexprPos = "/" }, { text = "Nat" } } }
        mock_client_request_rpc(this_client, saved_request_fn, fake_result)

        helpers.feed '<CR>'
        local tooltip = helpers.wait_for_new_window(known_windows)
        assert.contents.are {
          'a',
          buffer = tooltip:buffer(),
        }

        -- Close the tooltip.
        helpers.feed '<Esc>'
        assert.windows.are(known_windows)
      end)

      it('shows widget tooltips, no exprExplicit', function()
        helpers.move_cursor { to = { 1, 9 } }
        assert.infoview_contents.are [[
        Goals accomplished 🎉

        ▼ expected type (1:10-1:11)
        ⊢ ∃ a, a = 3]]

        current_infoview:enter()
        helpers.move_cursor { to = { 4, 8 } } -- `a`

        local known_windows = { lean_window, current_infoview.window }
        assert.windows.are(known_windows)

        save_client_stuff()
        local fake_result = {
          doc = vim.NIL,
          exprExplicit = vim.NIL,
          type = { tag = { { info = { p = "14" }, subexprPos = "/" }, { text = "Nat" } } }
        }
        mock_client_request_rpc(this_client, saved_request_fn, fake_result)

        helpers.feed '<CR>'
        local tooltip = helpers.wait_for_new_window(known_windows)
        assert.contents.are {
          'Nat',
          buffer = tooltip:buffer(),
        }

        -- Close the tooltip.
        helpers.feed '<Esc>'
        assert.windows.are(known_windows)
      end)

      it('shows widget tooltips nomock', function()
        helpers.move_cursor { to = { 1, 9 } }
        assert.infoview_contents.are [[
        Goals accomplished 🎉

        ▼ expected type (1:10-1:11)
        ⊢ ∃ a, a = 3]]

        current_infoview:enter()
        helpers.move_cursor { to = { 4, 8 } } -- `a`

        local known_windows = { lean_window, current_infoview.window }
        assert.windows.are(known_windows)

        helpers.feed '<CR>'
        local tooltip = helpers.wait_for_new_window(known_windows)
        assert.contents.are {
          'a : Nat',
          buffer = tooltip:buffer(),
        }

        -- Close the tooltip.
        helpers.feed '<Esc>'
        assert.windows.are(known_windows)
      end)

    end
  )
)
