local dedent = require('std.text').dedent
local Element = require('lean.tui').Element
local Tabs = require 'tui.tabs'

---Find a clickable label whose text contains `name`.
local function tab(el, name)
  return el:find(function(child)
    return child.events and child.events.click and child.text and child.text:find(name, 1, true)
  end)
end

---Find any element whose text contains `name`.
local function label(el, name)
  return el:find(function(child)
    return child.text and child.text:find(name, 1, true)
  end)
end

---@type ElementEventContext
local NULL_CONTEXT = {
  rerender = function() end,
  rehover = function() end,
  jump_to_last_window = function() end,
}

describe('tui.tabs', function()
  it('renders the leftmost tab active with a closing left corner', function()
    local el = Tabs {
      tabs = {
        { label = 'percentile', body = Element.text 'P' },
        { label = 'visibility', body = Element.text 'V' },
      },
      active = 1,
    }
    -- The trailing pad after `visibility` is invisible but load-bearing:
    -- it keeps the inactive label aligned with the baseline below it.
    assert.is.equal(
      table.concat({
        '╭────────────╮',
        '│ percentile │  visibility  ',
        '╰────────────┴──────────────',
        'P',
      }, '\n'),
      el:to_string()
    )
  end)

  it('renders the rightmost tab active with a closing right corner', function()
    local el = Tabs {
      tabs = {
        { label = 'percentile', body = Element.text 'P' },
        { label = 'visibility', body = Element.text 'V' },
      },
      active = 2,
    }
    assert.is.equal(
      dedent [[
                      ╭────────────╮
          percentile  │ visibility │
        ──────────────┴────────────╯
        V]],
      el:to_string()
    )
  end)

  it('renders an interior active tab with junctions on both sides', function()
    local el = Tabs {
      tabs = {
        { label = 'a', body = Element.text 'A' },
        { label = 'b', body = Element.text 'B' },
        { label = 'c', body = Element.text 'C' },
      },
      active = 2,
    }
    -- Trailing pad on the rightmost inactive label is preserved on purpose
    -- so the baseline below stays aligned.
    assert.is.equal(
      table.concat({
        '     ╭───╮',
        '  a  │ b │  c  ',
        '─────┴───┴─────',
        'B',
      }, '\n'),
      el:to_string()
    )
  end)

  it('switches body and active tab when an inactive label is clicked', function()
    local el = Tabs {
      tabs = {
        { label = 'one', body = Element.text 'first' },
        { label = 'two', body = Element.text 'second' },
      },
      active = 1,
    }
    assert.is_truthy(el:to_string():find('first', 1, true))

    tab(el, 'two').events.click(NULL_CONTEXT)

    assert.is_truthy(el:to_string():find('second', 1, true))
    assert.is_falsy(el:to_string():find('first', 1, true))
  end)

  it('does not wire a click handler on the active tab', function()
    local el = Tabs {
      tabs = {
        { label = 'one', body = Element.text 'first' },
        { label = 'two', body = Element.text 'second' },
      },
      active = 1,
    }
    assert.is_nil(label(el, 'one').events.click)
  end)

  it('calls on_change with the new index', function()
    local seen
    local el = Tabs {
      tabs = {
        { label = 'one', body = Element.text 'first' },
        { label = 'two', body = Element.text 'second' },
      },
      active = 1,
      on_change = function(i)
        seen = i
      end,
    }
    tab(el, 'two').events.click(NULL_CONTEXT)
    assert.is.equal(2, seen)
  end)

  it('only resolves the active tab body lazily', function()
    local one_calls, two_calls = 0, 0
    local el = Tabs {
      tabs = {
        {
          label = 'one',
          body = function()
            one_calls = one_calls + 1
            return Element.text 'first'
          end,
        },
        {
          label = 'two',
          body = function()
            two_calls = two_calls + 1
            return Element.text 'second'
          end,
        },
      },
      active = 1,
    }
    assert.is.equal(1, one_calls)
    assert.is.equal(0, two_calls)

    tab(el, 'two').events.click(NULL_CONTEXT)
    assert.is.equal(1, one_calls)
    assert.is.equal(1, two_calls)
  end)
end)
