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

  describe('path navigation', function()
    ---@param element Element
    ---@return BufRenderer
    local function make_renderer(element)
      local buffer = Buffer.create { scratch = true }
      local renderer = element:renderer { buffer = buffer }
      renderer:render()
      return renderer
    end

    it('round-trips through a simple element', function()
      local element = Element:new { text = 'hello', name = 'root' }
      local renderer = make_renderer(element)

      local path = renderer:path_from_pos { 0, 0 }
      assert.is_not_nil(path)
      local pos = renderer:pos_from_path(path)
      assert.are.same({ 0, 0 }, pos)
      renderer.buffer:force_delete()
    end)

    it('navigates into the correct child', function()
      local a = Element:new { text = 'aaa', name = 'a' }
      local b = Element:new { text = 'bbb', name = 'b' }
      local root = Element:new { name = 'root', children = { a, b } }
      local renderer = make_renderer(root)

      local path_a, stack_a = renderer:path_from_pos { 0, 0 }
      assert.is_not_nil(path_a)
      assert.are.equal('a', stack_a[#stack_a].name)

      local path_b, stack_b = renderer:path_from_pos { 0, 3 }
      assert.is_not_nil(path_b)
      assert.are.equal('b', stack_b[#stack_b].name)
      renderer.buffer:force_delete()
    end)

    it('round-trips at every position in a multi-child element', function()
      local element = Element:new {
        text = 'R',
        name = 'root',
        children = {
          Element:new { text = 'aa', name = 'a' },
          Element:new { text = 'bbb', name = 'b' },
        },
      }
      local renderer = make_renderer(element)
      assert.contents.are { 'Raabbb', buffer = renderer.buffer }

      for line_idx, line in ipairs(renderer.buffer:lines()) do
        for col = 0, #line - 1 do
          local lc = { line_idx - 1, col }
          local path = renderer:path_from_pos(lc)
          assert.is_not_nil(path, ('no path at {%d, %d}'):format(lc[1], lc[2]))
          local rt = renderer:pos_from_path(path)
          assert.are.same(lc, rt, ('round-trip failed at {%d, %d}'):format(lc[1], lc[2]))
        end
      end
      renderer.buffer:force_delete()
    end)

    it('round-trips through nested children', function()
      local leaf = Element:new { text = 'leaf', name = 'leaf' }
      local mid = Element:new { text = 'M', name = 'mid', children = { leaf } }
      local root = Element:new { text = 'R', name = 'root', children = { mid } }
      local renderer = make_renderer(root)
      assert.contents.are { 'RMleaf', buffer = renderer.buffer }

      for line_idx, line in ipairs(renderer.buffer:lines()) do
        for col = 0, #line - 1 do
          local lc = { line_idx - 1, col }
          local path = renderer:path_from_pos(lc)
          assert.is_not_nil(path, ('no path at {%d, %d}'):format(lc[1], lc[2]))
          local rt = renderer:pos_from_path(path)
          assert.are.same(lc, rt, ('round-trip failed at {%d, %d}'):format(lc[1], lc[2]))
        end
      end
      renderer.buffer:force_delete()
    end)

    it('round-trips through multi-line content', function()
      local element = Element:new {
        text = 'line1\n',
        name = 'root',
        children = {
          Element:new { text = 'line2\n', name = 'a' },
          Element:new { text = 'line3', name = 'b' },
        },
      }
      local renderer = make_renderer(element)
      assert.contents.are { 'line1\nline2\nline3', buffer = renderer.buffer }

      for line_idx, line in ipairs(renderer.buffer:lines()) do
        for col = 0, #line - 1 do
          local lc = { line_idx - 1, col }
          local path = renderer:path_from_pos(lc)
          assert.is_not_nil(path, ('no path at {%d, %d}'):format(lc[1], lc[2]))
          local rt = renderer:pos_from_path(path)
          assert.are.same(lc, rt, ('round-trip failed at {%d, %d}'):format(lc[1], lc[2]))
        end
      end
      renderer.buffer:force_delete()
    end)

    it('returns nil for out-of-bounds positions', function()
      local element = Element:new { text = 'abc', name = 'root' }
      local renderer = make_renderer(element)
      assert.is_nil(renderer:path_from_pos { 99, 0 })
      renderer.buffer:force_delete()
    end)

    it('returns nil for an invalid path', function()
      local element = Element:new { text = 'abc', name = 'root' }
      local renderer = make_renderer(element)
      assert.is_nil(renderer:pos_from_path { { idx = 0, name = 'wrong' } })
      renderer.buffer:force_delete()
    end)
  end)

  describe('hlgroups', function()
    ---Render element into a scratch buffer and return the applied highlights
    ---as `{ hl_group, text }` pairs, sorted for determinism.
    ---@param element Element
    ---@return { [1]: string, [2]: string }[]
    local function rendered_highlights(element)
      local buffer = Buffer.create { name = 'test-hlgroups' }
      element:renderer({ buffer = buffer }):render()
      local marks =
        buffer:extmarks(vim.api.nvim_create_namespace 'lean.tui', 0, -1, { details = true })
      local highlights = vim
        .iter(marks)
        :map(function(m)
          local text =
            vim.api.nvim_buf_get_text(buffer.bufnr, m[2], m[3], m[4].end_row, m[4].end_col, {})
          return { m[4].hl_group, table.concat(text, '\n') }
        end)
        :totable()
      buffer:force_delete()
      table.sort(highlights, function(a, b)
        return a[1] < b[1]
      end)
      return highlights
    end

    it('applies a single highlight group', function()
      local element = Element:new { text = 'foo', hlgroups = { 'String' } }
      assert.are.same({ { 'String', 'foo' } }, rendered_highlights(element))
    end)

    it('applies multiple highlight groups to the same text', function()
      local element = Element:new { text = 'foo', hlgroups = { 'String', 'Comment' } }
      assert.are.same({ { 'Comment', 'foo' }, { 'String', 'foo' } }, rendered_highlights(element))
    end)

    it('applies highlight groups returned by a function', function()
      local element = Element:new {
        text = 'foo',
        hlgroups = function()
          return { 'String', 'Comment' }
        end,
      }
      assert.are.same({ { 'Comment', 'foo' }, { 'String', 'foo' } }, rendered_highlights(element))
    end)

    it('applies no highlights when a function returns nil', function()
      local element = Element:new {
        text = 'foo',
        hlgroups = function()
          return nil
        end,
      }
      assert.are.same({}, rendered_highlights(element))
    end)

    it('the parent highlight spans child text too', function()
      local element = Element:new {
        text = 'foo',
        hlgroups = { 'String' },
        children = { Element:new { text = 'bar', hlgroups = { 'Comment' } } },
      }
      assert.are.same(
        { { 'Comment', 'bar' }, { 'String', 'foobar' } },
        rendered_highlights(element)
      )
    end)

    it('highlights a child on the second line', function()
      local element = Element:new {
        text = 'first line\n',
        children = {
          Element:new { text = 'second', hlgroups = { 'String' } },
        },
      }
      assert.are.same({ { 'String', 'second' } }, rendered_highlights(element))
    end)

    it('highlights text spanning multiple lines', function()
      local element = Element:new {
        text = 'spans\ntwo lines',
        hlgroups = { 'Comment' },
      }
      assert.are.same({ { 'Comment', 'spans\ntwo lines' } }, rendered_highlights(element))
    end)

    it('highlights multiple children across lines', function()
      local element = Element:new {
        children = {
          Element:new { text = 'aaa', hlgroups = { 'String' } },
          Element:new { text = '\n' },
          Element:new { text = 'bbb', hlgroups = { 'Comment' } },
        },
      }
      local hls = rendered_highlights(element)
      assert.are.same({ { 'Comment', 'bbb' }, { 'String', 'aaa' } }, hls)
    end)

    it('highlights a parent spanning children across lines', function()
      local element = Element:new {
        text = 'top',
        hlgroups = { 'Title' },
        children = {
          Element:new { text = '\nbottom' },
        },
      }
      assert.are.same({ { 'Title', 'top\nbottom' } }, rendered_highlights(element))
    end)
  end)

  describe(':titled', function()
    it('creates an element with a title and body', function()
      local foo = Element:new { text = 'foo', name = 'foo-name' }
      local bar = Element:new { text = 'bar bar\n', name = 'bar-name' }
      local baz = Element:new { name = 'baz-name' }

      local element = Element:titled {
        title = Element:new { text = 'quux' },
        body = { foo, bar, baz },
      }

      assert.is.equal(
        dedent [[
          quux

          foobar bar
        ]],
        element:to_string()
      )
    end)

    it('supports arbitrary margin', function()
      local foo = Element:new { text = 'foo\nbar\n' }
      local element = Element:titled {
        title = Element:new { text = 'stuff' },
        margin = 3,
        body = { foo },
      }

      assert.is.equal(
        dedent [[
          stuff


          foo
          bar
        ]],
        element:to_string()
      )
    end)

    it('returns the title element when body is empty', function()
      local title = Element:new { text = 'stuff' }
      assert.are.equal(title, Element:titled { title = title, body = {} })
    end)

    it('returns the title element when body is nil', function()
      local title = Element:new { text = 'stuff' }
      assert.are.equal(title, Element:titled { title = title })
    end)

    it('returns nil when title is omitted and body is empty', function()
      assert.is_nil(Element:titled { body = {} })
    end)

    it('returns nil when both title and body are omitted', function()
      assert.is_nil(Element:titled {})
    end)

    it('returns just the body when title is omitted', function()
      local foo = Element:new { text = 'foo' }
      local bar = Element:new { text = 'bar' }

      local element = Element:titled { body = { foo, bar } }

      assert.is.equal('foobar', element:to_string())
    end)
  end)

  describe(':foldable', function()
    it('renders with an arrow and body when open', function()
      local foo = Element:new { text = 'foo', name = 'foo-name' }
      local bar = Element:new { text = 'bar bar\n', name = 'bar-name' }
      local baz = Element:new { name = 'baz-name' }

      local element = Element:foldable {
        title = Element:new { text = 'quux' },
        body = { foo, bar, baz },
      }

      assert.is.equal(
        dedent [[
          ▼ quux

          foobar bar
        ]],
        element:to_string()
      )
    end)

    it('supports arbitrary margin lines between title and body', function()
      local foo = Element:new { text = 'foo\nbar\n' }
      local element = Element:foldable {
        title = Element:new { text = 'stuff' },
        margin = 3,
        body = { foo },
      }

      assert.is.equal(
        dedent [[
          ▼ stuff


          foo
          bar
        ]],
        element:to_string()
      )
    end)

    it('collapses body on click', function()
      local foo = Element:new { text = 'foo' }
      local bar = Element:new { text = 'bar' }

      local element = Element:foldable {
        title = Element:new { text = 'quux' },
        body = { foo, bar },
      }

      assert.is.equal('▼ quux\n\nfoobar', element:to_string())

      local title_row = element:find(function(child)
        return child.events and child.events.click
      end)
      title_row.events.click(NULL_CONTEXT)

      assert.is.equal('▶ quux', element:to_string())
    end)

    it('expands body on second click', function()
      local foo = Element:new { text = 'foo' }

      local element = Element:foldable {
        title = Element:new { text = 'quux' },
        body = { foo },
      }

      local title_row = element:find(function(child)
        return child.events and child.events.click
      end)
      title_row.events.click(NULL_CONTEXT)
      assert.is.equal('▶ quux', element:to_string())

      title_row.events.click(NULL_CONTEXT)
      assert.is.equal('▼ quux\n\nfoo', element:to_string())
    end)

    it('starts collapsed when open is false', function()
      local foo = Element:new { text = 'foo' }

      local element = Element:foldable {
        title = Element:new { text = 'quux' },
        body = { foo },
        open = false,
      }

      assert.is.equal('▶ quux', element:to_string())

      local title_row = element:find(function(child)
        return child.events and child.events.click
      end)
      title_row.events.click(NULL_CONTEXT)

      assert.is.equal('▼ quux\n\nfoo', element:to_string())
    end)

    it('calls on_open when expanding', function()
      local placeholder = Element:new { text = 'loading...' }
      local real_content = Element:new { text = 'loaded!' }

      local element = Element:foldable {
        title = Element:new { text = 'lazy' },
        body = { placeholder },
        open = false,
        on_open = function(body)
          body:set_children { real_content }
        end,
      }

      assert.is.equal('▶ lazy', element:to_string())

      local title_row = element:find(function(child)
        return child.events and child.events.click
      end)
      title_row.events.click(NULL_CONTEXT)

      assert.is.equal('▼ lazy\n\nloaded!', element:to_string())
    end)

    it('preserves hlgroups from the title element', function()
      local title = Element:new { text = 'styled', hlgroups = { 'Title' } }
      local foo = Element:new { text = 'body' }

      local element = Element:foldable { title = title, body = { foo }, margin = 0 }

      assert.is.equal('▼ styledbody', element:to_string())

      local title_row = element:find(function(child)
        return child.events and child.events.click
      end)
      title_row.events.click(NULL_CONTEXT)

      assert.is.equal('▶ styled', element:to_string())
    end)

    it('supports rich Element titles', function()
      local title = Element:new {
        children = {
          Element:new { text = 'hello ' },
          Element:new { text = 'world' },
        },
      }

      local element = Element:foldable { title = title, body = { Element:new { text = 'body' } } }

      assert.is.equal('▼ hello world\n\nbody', element:to_string())
    end)

    it('returns the title element when body is empty', function()
      local title = Element:new { text = 'stuff' }
      local element = Element:foldable { title = title, body = {} }

      assert.are.equal(title, element)
      assert.is.equal('stuff', element:to_string())
    end)

    it('calls on_close when folded', function()
      local closed = false
      local element = Element:foldable {
        title = Element:new { text = 'title' },
        body = { Element:new { text = 'body' } },
        on_close = function()
          closed = true
        end,
      }

      local title_row = element:find(function(child)
        return child.events and child.events.click
      end)
      -- Starts open; clicking closes.
      title_row.events.click(NULL_CONTEXT)
      assert.is_true(closed)
    end)

    it('calls on_open and on_close symmetrically', function()
      local log = {}
      local function track()
        table.insert(log, 'toggled')
      end
      local element = Element:foldable {
        title = Element:new { text = 'title' },
        body = { Element:new { text = 'body' } },
        on_open = track,
        on_close = track,
      }

      local title_row = element:find(function(child)
        return child.events and child.events.click
      end)
      title_row.events.click(NULL_CONTEXT) -- close
      title_row.events.click(NULL_CONTEXT) -- open
      title_row.events.click(NULL_CONTEXT) -- close
      assert.are.same({ 'toggled', 'toggled', 'toggled' }, log)
    end)

    it('returns the title element when body is nil', function()
      local title = Element:new { text = 'stuff' }
      local element = Element:foldable { title = title }

      assert.are.equal(title, element)
      assert.is.equal('stuff', element:to_string())
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

  describe('link', function()
    it('wires action to the click event', function()
      local called = false
      local element = Element.link {
        text = 'click me',
        action = function()
          called = true
        end,
      }
      element.events.click(NULL_CONTEXT)
      assert.is_true(called)
    end)

    it('uses explicit events when provided', function()
      local def_called = false
      local decl_called = false
      local element = Element.link {
        text = 'go',
        events = {
          go_to_def = function()
            def_called = true
          end,
          go_to_decl = function()
            decl_called = true
          end,
        },
      }
      element.events.go_to_def(NULL_CONTEXT)
      element.events.go_to_decl(NULL_CONTEXT)
      assert.is_true(def_called)
      assert.is_true(decl_called)
    end)

    it('errors when both action and events are provided', function()
      assert.has_error(function()
        Element.link {
          text = 'bad',
          action = function() end,
          events = { click = function() end },
        }
      end, 'Element.link: provide action or events, not both')
    end)

    it('errors when neither action nor events is provided', function()
      assert.has_error(function()
        Element.link { text = 'inert' }
      end, 'Element.link: one of action or events is required')
    end)

    it('enforces link styling', function()
      local element = Element.link {
        text = 'styled',
        action = function() end,
      }
      assert.is_true(element.highlightable)
      assert.are.same({ 'widgetLink' }, element.hlgroups)
    end)

    it('passes through text, name, and children', function()
      local child = Element:new { text = 'child' }
      local element = Element.link {
        text = 'link',
        name = 'my-link',
        children = { child },
        action = function() end,
      }
      assert.are.same('my-link', element.name)
      assert.are.same('linkchild', element:to_string())
    end)
  end)

  describe('kbd', function()
    it('creates an element representing a keyboard input sequence', function()
      assert.are.same(Element:new { text = 'Ctrl', hlgroups = { 'widgetKbd' } }, Element.kbd 'Ctrl')
    end)
  end)

  describe(':renderer', function()
    it('creates a BufRenderer rendering the element', function()
      local buffer = Buffer.create { name = 'foo-buffer' }
      local element = Element:new { text = 'foo', name = 'foo-name' }
      local renderer = element:renderer { buffer = buffer }
      assert.are.equal(buffer.bufnr, renderer.buffer.bufnr)
      assert.are.equal(element, renderer.element)
      buffer:delete()
    end)
  end)
end)

describe('BufRenderer', function()
  describe(':render', function()
    it('sets buffer lines from the element', function()
      local buffer = Buffer.create { scratch = true }
      local element = Element:new {
        text = 'line1\n',
        children = {
          Element:new { text = 'line2\n' },
          Element:new { text = 'line3' },
        },
      }
      local renderer = element:renderer { buffer = buffer }
      renderer:render()
      assert.contents.are { 'line1\nline2\nline3', buffer = buffer }
      buffer:force_delete()
    end)
  end)

  describe(':buf_position_from_path', function()
    it('returns nil before the first render', function()
      local buffer = Buffer.create { scratch = true }
      local element = Element:new { text = 'hello', name = 'root' }
      local renderer = element:renderer { buffer = buffer }
      -- lines is nil before render
      assert.is_nil(renderer:buf_position_from_path { { idx = 0, name = 'root' } })
      buffer:force_delete()
    end)

    it('returns the (1,0)-indexed position for the root', function()
      local buffer = Buffer.create { scratch = true }
      local element = Element:new { text = 'hello', name = 'root' }
      local renderer = element:renderer { buffer = buffer }
      renderer:render()

      local pos = renderer:buf_position_from_path { { idx = 0, name = 'root' } }
      assert.are.same({ 1, 0 }, pos)
      buffer:force_delete()
    end)

    it('returns positions for children on different lines', function()
      local buffer = Buffer.create { scratch = true }
      local element = Element:new {
        text = 'first\n',
        name = 'root',
        children = {
          Element:new { text = 'second\n', name = 'a' },
          Element:new { text = 'third', name = 'b' },
        },
      }
      local renderer = element:renderer { buffer = buffer }
      renderer:render()

      local pos_root = renderer:buf_position_from_path { { idx = 0, name = 'root' } }
      assert.are.same({ 1, 0 }, pos_root)

      local pos_a = renderer:buf_position_from_path {
        { idx = 0, name = 'root' },
        { idx = 1, name = 'a' },
      }
      assert.are.same({ 2, 0 }, pos_a)

      local pos_b = renderer:buf_position_from_path {
        { idx = 0, name = 'root' },
        { idx = 2, name = 'b' },
      }
      assert.are.same({ 3, 0 }, pos_b)

      buffer:force_delete()
    end)

    it('returns correct column for children mid-line', function()
      local buffer = Buffer.create { scratch = true }
      local element = Element:new {
        text = 'AB',
        name = 'root',
        children = {
          Element:new { text = 'CD', name = 'a' },
          Element:new { text = 'EF', name = 'b' },
        },
      }
      local renderer = element:renderer { buffer = buffer }
      renderer:render()

      local pos_a = renderer:buf_position_from_path {
        { idx = 0, name = 'root' },
        { idx = 1, name = 'a' },
      }
      assert.are.same({ 1, 2 }, pos_a)

      local pos_b = renderer:buf_position_from_path {
        { idx = 0, name = 'root' },
        { idx = 2, name = 'b' },
      }
      assert.are.same({ 1, 4 }, pos_b)

      buffer:force_delete()
    end)
  end)

  describe('hover highlighting', function()
    it('highlights a highlightable element when hovered', function()
      local buffer = Buffer.create { scratch = true }
      local element = Element:new {
        name = 'root',
        children = {
          Element:new { text = 'normal ' },
          Element:new {
            text = 'clickable',
            highlightable = true,
            events = { click = function() end },
          },
        },
      }
      local renderer = element:renderer { buffer = buffer }
      renderer:render()

      -- Simulate the cursor being on 'clickable' (starts at column 7)
      local window = Window:current()
      vim.api.nvim_set_current_buf(buffer.bufnr)
      window:set_cursor { 1, 7 }
      renderer:update_cursor(window)

      assert.is_not_nil(renderer.hover_range)
      -- hover_range is (0,0)-indexed
      assert.are.same({ 0, 7 }, renderer.hover_range[1])
      assert.are.same({ 0, 16 }, renderer.hover_range[2])

      buffer:force_delete()
    end)

    it('clears hover highlight when path is nil', function()
      local buffer = Buffer.create { scratch = true }
      local element = Element:new {
        name = 'root',
        text = 'hello',
      }
      local renderer = element:renderer { buffer = buffer }
      renderer:render()

      renderer.path = nil
      renderer:hover()

      assert.is_nil(renderer.hover_range)

      buffer:force_delete()
    end)
  end)

  describe(':event', function()
    it('dispatches root-level handlers when no cursor path has been set', function()
      local fired = false
      local buffer = Buffer.create { scratch = true }
      local element = Element:new {
        name = 'root',
        text = 'hello',
        events = {
          clear = function()
            fired = true
          end,
        },
      }
      local renderer = element:renderer { buffer = buffer }
      renderer:render()
      assert.is_nil(renderer.path)

      renderer:event 'clear'

      assert.is_true(fired)
      buffer:force_delete()
    end)

    it('does not fire child handlers when no path has been set', function()
      local fired = false
      local buffer = Buffer.create { scratch = true }
      local element = Element:new {
        name = 'root',
        children = {
          Element:new {
            text = 'child',
            events = {
              click = function()
                fired = true
              end,
            },
          },
        },
      }
      local renderer = element:renderer { buffer = buffer }
      renderer:render()
      assert.is_nil(renderer.path)

      renderer:event 'click'

      assert.is_false(fired)
      buffer:force_delete()
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
        buffer = tooltip:buffer(),
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
