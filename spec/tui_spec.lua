---@brief [[
--- Tests for the console UI framework in isolation from Lean-specific widgets.
---@brief ]]

local Buffer = require 'std.nvim.buffer'
local Window = require 'std.nvim.window'
local dedent = require('std.text').dedent

local helpers = require 'spec.helpers'
local tui = require 'lean.tui'
local Element = tui.Element

---A silly fake event context.
---@type ElementEventContext
local NULL_CONTEXT = {
  rerender = function() end,
  rehover = function() end,
  jump_to_last_window = function() end,
}

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

    describe('with opts', function()
      it('preserves opts when elements has one item', function()
        local called = false
        local foo = Element:new { text = 'foo' }
        local element = Element:concat({ foo }, '\n', {
          events = {
            test_event = function()
              called = true
            end,
          },
          name = 'single_concat',
        })

        assert.is_not_nil(element)
        assert.is.same('single_concat', element.name)
        assert.is.not_nil(element.events.test_event)

        element.events.test_event()
        assert.is_true(called)
      end)

      it('preserves opts when elements has multiple items', function()
        local called = false
        local foo = Element:new { text = 'foo' }
        local bar = Element:new { text = 'bar' }
        local element = Element:concat({ foo, bar }, '\n', {
          events = {
            test_event = function()
              called = true
            end,
          },
          name = 'multi_concat',
        })

        assert.is_not_nil(element)
        assert.is.same('multi_concat', element.name)
        assert.is.not_nil(element.events.test_event)

        element.events.test_event()
        assert.is_true(called)
      end)

      it('errors when given opts with no elements', function()
        assert.has_error(function()
          Element:concat({}, '\n', {
            events = {
              test_event = function() end,
            },
            name = 'empty_concat',
          })
        end, 'opts: expected nil, got table')
      end)
    end)
  end)

  describe(':walk', function()
    it('walks an element with children', function()
      local foo = Element:new { text = 'foo' }
      local bar = Element:new { text = 'bar' }
      local baz = Element:new { children = { bar } }

      local element = Element:new {
        text = 'quux',
        children = { foo, baz },
      }

      local visited = vim.iter(element:walk()):totable()
      assert.are.same({ element, foo, baz, bar }, visited)
    end)

    it('walks a single element', function()
      local element = Element:new { text = 'foo' }
      local visited = vim.iter(element:walk()):totable()
      assert.are.same({ element }, visited)
    end)
  end)

  describe(':find', function()
    it('finds a child matching a predicate', function()
      local foo = Element:new { text = 'foo' }
      local bar = Element:new { text = 'bar' }
      local baz = Element:new { children = { bar } }

      local element = Element:new {
        text = 'quux',
        children = { foo, baz },
      }

      assert.are.same(
        bar,
        element:find(function(e)
          return e.text == 'bar'
        end)
      )
    end)

    it('returns the element itself if it matches the predicate', function()
      local foo = Element:new { text = 'foo' }
      local bar = Element:new { text = 'bar' }
      local baz = Element:new { children = { bar } }

      local element = Element:new {
        text = 'quux',
        children = { foo, baz },
      }

      assert.are.same(
        element,
        element:find(function()
          return true
        end)
      )
    end)

    it('returns nil if no element is found', function()
      local element = Element:new {}
      assert.is_nil(element:find(function()
        return false
      end))
    end)
  end)

  describe(':filter', function()
    it('returns all elements matching a predicate', function()
      local foo = Element:new { text = 'foo' }
      local bar = Element:new { text = 'bar' }
      local baz = Element:new { children = { bar } }

      local element = Element:new {
        text = 'quux',
        children = { foo, baz },
      }

      local filtered = element:filter(function(e)
        return e.text == 'bar' or e.text == 'quux'
      end)

      assert.are.same({ element, bar }, filtered:totable())
    end)

    it('returns an empty iterator when no elements match', function()
      local foo = Element:new { text = 'foo' }
      local bar = Element:new { text = 'bar' }
      local baz = Element:new { children = { bar } }

      local element = Element:new {
        text = 'quux',
        children = { foo, baz },
      }

      local filtered = element:filter(function(e)
        return e.text == 'nonexistent'
      end)

      assert.are.same({}, filtered:totable())
    end)
  end)

  describe('select', function()
    local original_select = vim.ui.select

    after_each(function()
      vim.ui.select = original_select
    end)

    it('creates an element representing a selectable choice', function()
      vim.ui.select = function(choices, opts, on_choice)
        assert.are.equal(opts.prompt, 'Select a color')
        on_choice(choices[3])
      end

      local element = Element.select({ 'red', 'green', 'blue' }, {
        prompt = 'Select a color',
        initial = 'green',
      })

      assert.are.equal('green ▾', element:to_string())

      element.events.click(NULL_CONTEXT)

      assert.are.equal('blue ▾', element:to_string())
    end)

    it('supports more complicated selectable items', function()
      local function format_item(item)
        return item .. item
      end

      vim.ui.select = function(choices, opts, on_choice)
        assert.are.same(opts, { format_item = format_item })
        on_choice(choices[3])
      end

      local element = Element.select({ 'red', 'green', 'blue' }, {
        format_item = format_item,
        initial = 'green',
      })

      assert.are.equal('greengreen ▾', element:to_string())

      element.events.click(NULL_CONTEXT)

      assert.are.equal('blueblue ▾', element:to_string())
    end)
  end)

  describe('kbd', function()
    it('creates an element representing a keyboard input sequence', function()
      assert.are.same(Element:new { text = 'Ctrl', hlgroup = 'widgetKbd' }, Element.kbd 'Ctrl')
    end)
  end)

  describe(':renderer', function()
    it('creates a BufRenderer rendering the element', function()
      local buffer = Buffer.create { name = 'foo-buffer' }
      local element = Element:new { text = 'foo', name = 'foo-name' }
      assert.is.same(
        tui.BufRenderer:new { buffer = buffer, element = element },
        element:renderer { buffer = buffer }
      )
      buffer:delete()
    end)
  end)
end)

describe(
  'select_many',
  helpers.clean_buffer(function()
    local initial_window = Window:current()

    it('interactively selects between choices', function()
      local selected

      tui.select_many({ 'foo', 'bar', 'baz' }, nil, function(choices)
        selected = choices
      end)
      local popup = helpers.wait_for_new_window { initial_window }

      assert.is_true(popup:is_current())
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

      assert.are.same({ { 'bar', 'baz' }, initial_window }, { selected, Window:current() })
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
        bufnr = tooltip:bufnr(),
      }

      helpers.feed '<Esc>'

      -- FIXME: Are we abandoning tooltip windows?
      -- Why is clear_all so hard to define?
      tooltip:close()
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

      selection_window:close()
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
