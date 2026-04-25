local dedent = require('std.text').dedent
local Element = require('lean.tui').Element
local Table = require 'tui.table'

describe('Table', function()
  it('renders a simple table with column alignment', function()
    local el = Table.render {
      Table.row { Element.text 'a', Element.text 'b' },
      Table.row { Element.text 'cc', Element.text 'd' },
    }
    assert.is.equal(
      dedent [[
        a  │ b
        cc │ d]],
      el:to_string()
    )
  end)

  it('renders a table with header separator', function()
    local el = Table.render {
      Table.header { Element.text 'Name', Element.text 'N' },
      Table.row { Element.text 'x', Element.text '3' },
    }
    assert.is.equal(
      dedent [[
        Name │ N
        ─────┼──
        x    │ 3]],
      el:to_string()
    )
  end)

  it('renders an empty table', function()
    local el = Table.render {}
    assert.is.equal('', el:to_string())
  end)

  it('renders multiple header rows', function()
    local el = Table.render {
      Table.header { Element.text 'A', Element.text 'B' },
      Table.header { Element.text 'a', Element.text 'b' },
      Table.row { Element.text 'x', Element.text 'y' },
    }
    assert.is.equal(
      dedent [[
        A │ B
        ──┼──
        a │ b
        ──┼──
        x │ y]],
      el:to_string()
    )
  end)

  it('renders a foldable row collapsed by default', function()
    local el = Table.render {
      Table.row { Element.text 'plain', Element.text '1' },
      Table.foldable {
        cells = { Element.text 'parent', Element.text '2' },
        children = {
          Table.row { Element.text 'child', Element.text '3' },
        },
      },
    }
    -- Collapsed: child not visible, plain row indented to align with arrow.
    assert.is.equal(
      dedent [[
          plain  │ 1
        ▶ parent │ 2]],
      el:to_string()
    )
  end)

  it('indents child rows consistently when foldable is present', function()
    -- Even without a nested foldable among children, they should
    -- inherit the parent prefix for consistent indentation.
    local el = Table.render {
      Table.foldable {
        cells = { Element.text 'p', Element.text '1' },
        children = {
          Table.row { Element.text 'a', Element.text '2' },
          Table.row { Element.text 'b', Element.text '3' },
        },
        open = true,
      },
    }
    local text = el:to_string()
    -- All child rows should have consistent indentation.
    assert.is_truthy(text:find('  a │ 2', 1, true), 'child a should be indented')
    assert.is_truthy(text:find('  b │ 3', 1, true), 'child b should be indented')
  end)
end)
