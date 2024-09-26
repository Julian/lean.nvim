---@brief [[
---Tests for the console UI framework in isolation from Lean-specific widgets.
---@brief ]]

local helpers = require 'spec.helpers'
local tui = require 'lean.tui'
local Element = tui.Element

describe('Element:concat', function()
  it('creates an Element concatenated by a separator', function()
    local foo = Element:new { text = 'foo', name = 'foo-name' }
    local bar = Element:new { text = 'bar bar', name = 'bar-name' }
    local baz = Element:new { name = 'baz-name' }

    local element = Element:concat({ foo, bar, baz }, '\n\n')

    assert.is.same(
      Element:new {
        children = {
          foo,
          Element:new { text = '\n\n' },
          bar,
          Element:new { text = '\n\n' },
          baz,
        },
      },
      element
    )
  end)
end)

describe('Element:renderer', function()
  it('creates a BufRenderer rendering the element', function()
    local element = Element:new { text = 'foo', name = 'foo-name' }
    assert.is.same(tui.BufRenderer:new { buf = 1, element = element }, element:renderer { buf = 1 })
  end)
end)

describe(
  'select_many',
  helpers.clean_buffer(function()
    local initial_window = vim.api.nvim_get_current_win()

    it('interactively selects between choices', function()
      local selected

      tui.select_many({ 'foo', 'bar', 'baz' }, nil, function(choices)
        selected = choices
      end)
      local popup = helpers.wait_for_new_window { initial_window }

      assert.are.equal(popup, vim.api.nvim_get_current_win())
      -- Sigh, force a BufEnter to make sure BufRenderer:update_position is
      -- called, which doesn't happen automatically here but does interactively.
      vim.cmd.doautocmd 'BufEnter'

      local FRIGGING_WHITESPACE = '      '
      assert.contents.are(FRIGGING_WHITESPACE .. '\n' .. [[
       ✅ foo
       ✅ bar
       ✅ baz
      ]] .. '\n' .. FRIGGING_WHITESPACE)

      -- toggle what should be the first option
      helpers.feed '<Tab>'

      assert.contents.are(FRIGGING_WHITESPACE .. '\n' .. [[
       ❌ foo
       ✅ bar
       ✅ baz
      ]] .. '\n' .. FRIGGING_WHITESPACE)

      helpers.feed '<CR>'

      assert.are.same(
        { { 'bar', 'baz' }, initial_window },
        { selected, vim.api.nvim_get_current_win() }
      )
    end)

    it('formats items as specified', function()
      local selected

      tui.select_many({
        { description = 'foo' },
        { description = 'bar' },
        { description = 'baz' },
      }, {
        format_item = function(item)
          return item.description
        end,
      }, function(choices)
        selected = choices
      end)

      helpers.wait_for_new_window { initial_window }
      -- Sigh, force a BufEnter to make sure BufRenderer:update_position is
      -- called, which doesn't happen automatically here but does interactively.
      vim.cmd.doautocmd 'BufEnter'

      local FRIGGING_WHITESPACE = '      '
      assert.contents.are(FRIGGING_WHITESPACE .. '\n' .. [[
       ✅ foo
       ✅ bar
       ✅ baz
      ]] .. '\n' .. FRIGGING_WHITESPACE)

      helpers.feed '<Tab>jj'
      vim.cmd.doautocmd 'CursorMoved'
      helpers.feed '<Tab>'

      assert.contents.are(FRIGGING_WHITESPACE .. '\n' .. [[
       ❌ foo
       ✅ bar
       ❌ baz
      ]] .. '\n' .. FRIGGING_WHITESPACE)

      helpers.feed '<CR>'

      assert.are.same({ { description = 'bar' } }, selected)
    end)

    it('returns the unselected choices second', function()
      local selected, unselected

      tui.select_many({ 1, 2, 3 }, nil, function(chosen, unchosen)
        selected = chosen
        unselected = unchosen
      end)

      helpers.wait_for_new_window { initial_window }
      -- Sigh, force a BufEnter to make sure BufRenderer:update_position is
      -- called, which doesn't happen automatically here but does interactively.
      vim.cmd.doautocmd 'BufEnter'

      helpers.feed '<Tab>jj'
      vim.cmd.doautocmd 'CursorMoved'
      helpers.feed '<Tab>'

      local FRIGGING_WHITESPACE = '      '
      assert.contents.are(FRIGGING_WHITESPACE .. '\n' .. [[
       ❌ 1
       ✅ 2
       ❌ 3
      ]] .. '\n' .. FRIGGING_WHITESPACE)

      helpers.feed '<CR>'

      assert.are.same({ { 2 }, { 1, 3 } }, { selected, unselected })
    end)
  end)
)
