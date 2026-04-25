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
end)
