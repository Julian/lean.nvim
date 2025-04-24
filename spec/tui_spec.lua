---@brief [[
--- Tests for the console UI framework in isolation from Lean-specific widgets.
---@brief ]]

local dedent = require('std.text').dedent

local helpers = require 'spec.helpers'
local tui = require 'lean.tui'
local Element = tui.Element

describe('Element', function()
  describe(':to_string', function()
    it('renders the element and its children', function()
      local child = Element:new { text = 'bar' }
      local nested = Element:new {
        children = {
          Element:new { text = ' ' },
          Element:new { text = 'baz' },
        },
      }
      local element = Element:new {
        text = 'foo\n',
        children = { child, nested },
      }
      assert.is.same('foo\nbar baz', element:to_string())
    end)

    it('renders an empty element', function()
      assert.is.same('', Element:new():to_string())
    end)
  end)

  describe(':titled', function()
    it('creates an Element with a title and children', function()
      local foo = Element:new { text = 'foo', name = 'foo-name' }
      local bar = Element:new { text = 'bar bar\n', name = 'bar-name' }
      local baz = Element:new { name = 'baz-name' }

      local element = Element:titled { title = 'quux', body = { foo, bar, baz } }

      assert.is.same(
        Element:new {
          children = {
            Element:new { text = 'quux' },
            Element:new { text = '\n\n' },
            Element:new { children = { foo, bar, baz } },
          },
        },
        element
      )

      assert.is.equal(
        dedent [[
          quux

          foobar bar
        ]],
        element:to_string()
      )
    end)

    it('supports arbitrary margin lines between title and body', function()
      local foo = Element:new { text = 'foo\nbar\n' }
      local element = Element:titled {
        title = 'stuff',
        margin = 3,
        body = { foo },
      }

      assert.is.same(
        Element:new {
          children = {
            Element:new { text = 'stuff' },
            Element:new { text = '\n\n\n' },
            Element:new { children = { foo } },
          },
        },
        element
      )

      assert.is.equal(
        dedent [[
          stuff


          foo
          bar
        ]],
        element:to_string()
      )
    end)

    it('creates a text Element when children is empty', function()
      local element = Element:titled { title = 'stuff', body = {} }

      assert.is.same(Element:new { text = 'stuff' }, element)

      assert.is.equal('stuff', element:to_string())
    end)

    it('creates a text Element when children is nil', function()
      local element = Element:titled { title = 'stuff' }

      assert.is.same(Element:new { text = 'stuff' }, element)
      assert.is.equal('stuff', element:to_string())
    end)

    it('returns nil when given only an empty title', function()
      assert.is_nil(Element:titled { title = '' })
    end)

    it('returns nil when given an empty title and no body', function()
      assert.is_nil(Element:titled { title = '', body = {} })
    end)

    it('does not add a newline when title is empty', function()
      local foo = Element:new { text = 'foo', name = 'foo-name' }
      local bar = Element:new { text = 'bar bar', name = 'bar-name' }
      local baz = Element:new { name = 'baz-name' }

      local element = Element:titled { title = '', body = { foo, bar, baz } }

      assert.is.same(Element:new { children = { foo, bar, baz } }, element)

      assert.is.equal('foobar bar', element:to_string())
    end)

    describe('title_hlgroup', function()
      it('creates an Element with a title and children', function()
        local foo = Element:new { text = 'foo', name = 'foo-name' }
        local bar = Element:new { text = 'bar bar\n', name = 'bar-name' }

        local element = Element:titled {
          title = 'quux',
          title_hlgroup = 'Title',
          body = { foo, bar },
        }

        assert.is.same(
          Element:new {
            children = {
              Element:new { text = 'quux', hlgroup = 'Title' },
              Element:new { text = '\n\n' },
              Element:new { children = { foo, bar } },
            },
          },
          element
        )

        assert.is.equal(
          dedent [[
            quux

            foobar bar
          ]],
          element:to_string()
        )
      end)

      it('creates a text Element when children is empty', function()
        local element = Element:titled {
          title = 'quux',
          title_hlgroup = 'Another',
          body = {},
        }

        assert.is.same(Element:new { text = 'quux', hlgroup = 'Another' }, element)
        assert.is.equal('quux', element:to_string())
      end)

      it('creates a text Element when children is nil', function()
        local element = Element:titled { title = 'stuff', title_hlgroup = 'Title' }

        assert.is.same(Element:new { text = 'stuff', hlgroup = 'Title' }, element)
        assert.is.equal('stuff', element:to_string())
      end)

      it('returns nil when given only an empty title', function()
        assert.is_nil(Element:titled { title = '', title_hlgroup = 'Title' })
      end)

      it('returns nil when given an empty title and no body', function()
        assert.is_nil(Element:titled { title = '', body = {}, title_hlgroup = 'Title' })
      end)

      it('does not add a newline when title is empty', function()
        local foo = Element:new { text = 'foo', name = 'foo-name' }
        local bar = Element:new { text = 'bar bar', name = 'bar-name' }
        local baz = Element:new { name = 'baz-name' }

        local element = Element:titled {
          title = '',
          title_hlgroup = 'Title',
          body = { foo, bar, baz },
        }

        assert.is.same(Element:new { children = { foo, bar, baz } }, element)
        assert.is.equal('foobar bar', element:to_string())
      end)
    end)
  end)

  describe(':concat', function()
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

    it('returns nil when given no elements', function()
      assert.is_nil(Element:concat({}, '\n'))
    end)

    it("doesn't introduce extra nesting when given one element", function()
      local foo = Element:new { text = 'foo', name = 'foo-name' }
      assert.is.same(Element:concat({ foo }, '\n'), foo)
    end)
  end)

  describe(':kbd', function()
    it('creates an element representing a keyboard input sequence', function()
      assert.are.same(Element:new { text = 'Ctrl', hlgroup = 'widgetKbd' }, Element.kbd 'Ctrl')
    end)
  end)

  describe(':renderer', function()
    it('creates a BufRenderer rendering the element', function()
      local element = Element:new { text = 'foo', name = 'foo-name' }
      assert.is.same(
        tui.BufRenderer:new { buf = 1, element = element },
        element:renderer { buf = 1 }
      )
    end)
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
      vim.api.nvim_exec_autocmds('BufEnter', {})

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
      vim.api.nvim_exec_autocmds('BufEnter', {})

      local FRIGGING_WHITESPACE = '      '
      assert.contents.are(FRIGGING_WHITESPACE .. '\n' .. [[
       ✅ foo
       ✅ bar
       ✅ baz
      ]] .. '\n' .. FRIGGING_WHITESPACE)

      helpers.feed '<Tab>jj'
      vim.api.nvim_exec_autocmds('CursorMoved', {})
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
      vim.api.nvim_exec_autocmds('BufEnter', {})

      helpers.feed '<Tab>jj'
      vim.api.nvim_exec_autocmds('CursorMoved', {})
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

    it('can preselect only a subset of choices', function()
      local selected, unselected

      tui.select_many({ 'foo', 'bar', 'baz', 'quux' }, {
        start_selected = function(choice)
          return choice == 'bar' or choice == 'quux'
        end,
      }, function(chosen, unchosen)
        selected = chosen
        unselected = unchosen
      end)

      helpers.wait_for_new_window { initial_window }
      -- Sigh, force a BufEnter to make sure BufRenderer:update_position is
      -- called, which doesn't happen automatically here but does interactively.
      vim.api.nvim_exec_autocmds('BufEnter', {})

      local FRIGGING_WHITESPACE = '      '
      assert.contents.are(FRIGGING_WHITESPACE .. '\n' .. [[
       ❌ foo
       ✅ bar
       ❌ baz
       ✅ quux
      ]] .. '\n' .. FRIGGING_WHITESPACE)

      helpers.feed 'j'
      vim.api.nvim_exec_autocmds('CursorMoved', {})
      helpers.feed '<Tab>'

      assert.contents.are(FRIGGING_WHITESPACE .. '\n' .. [[
       ❌ foo
       ❌ bar
       ❌ baz
       ✅ quux
      ]] .. '\n' .. FRIGGING_WHITESPACE)

      helpers.feed '<CR>'

      assert.are.same({ { 'quux' }, { 'foo', 'bar', 'baz' } }, { selected, unselected })
    end)

    it('shows tooltips when available', function()
      tui.select_many({ 'foo', 'bar', 'baz', 'quux' }, {
        tooltip_for = function(choice)
          return choice .. "'s tooltip"
        end,
      }, function() end)

      local selection_window = helpers.wait_for_new_window { initial_window }
      -- Sigh, force a BufEnter to make sure BufRenderer:update_position is
      -- called, which doesn't happen automatically here but does interactively.
      vim.api.nvim_exec_autocmds('BufEnter', {})

      helpers.feed 'K'
      local tooltip = helpers.wait_for_new_window { initial_window, selection_window }

      assert.contents.are {
        "foo's tooltip",
        bufnr = vim.api.nvim_win_get_buf(tooltip),
      }

      helpers.feed '<Esc>'

      -- FIXME: Are we abandoning tooltip windows?
      -- Why is clear_all so hard to define?
      vim.api.nvim_win_close(tooltip, true)
      assert.windows.are { initial_window }
    end)

    it('restricts the cursor to the entry lines', function()
      tui.select_many({ 'foo', 'bar', 'baz', 'quux' }, nil, function() end)

      local selection_window = helpers.wait_for_new_window { initial_window }

      -- Sigh, force a CursorMoved to make our autocmd fire
      -- which doesn't happen automatically here but does interactively.
      helpers.feed 'G'
      vim.api.nvim_exec_autocmds('CursorMoved', {})

      -- we end up on the last entry, not the blank line below it
      assert.current_line.is ' ✅ quux'

      helpers.feed 'gg'
      vim.api.nvim_exec_autocmds('CursorMoved', {})

      -- we end up on the first entry, not the blank line before it
      assert.current_line.is ' ✅ foo'

      vim.api.nvim_win_close(selection_window, true)
    end)

    it('autocloses if the window is left', function()
      assert.windows.are { initial_window }

      tui.select_many({ 'foo', 'bar', 'baz', 'quux' }, nil, function() end)

      local selection_window = helpers.wait_for_new_window { initial_window }
      assert.windows.are { initial_window, selection_window }

      vim.cmd.wincmd '%'

      -- FIXME: Here too we don't actually end up with just the initial window
      -- in tests...
      -- assert.windows.are{ initial_window }
    end)
  end)
)
