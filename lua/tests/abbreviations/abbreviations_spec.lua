local abbreviations = require('lean.abbreviations')

require('lean').setup{ abbreviations = { enable = true } }

describe('programmatic API', function()
  it('provides access to loaded abbreviations', function()
    assert.is.equal('α', abbreviations.load()['a'])
  end)

  it('provides reverse-lookup of loaded abbreviations', function()
    assert.is.same(
      { [2] = {'\\a', '\\Ga', '\\alpha'}},
      abbreviations.reverse_lookup('α')
    )
  end)

  it('allows random trailing junk', function()
    assert.is.same(
      {
        [3] = { '\\^-' },
        [5] = { '\\-', '\\-1', '\\sy', '\\^-1', '\\inv' },
      },
      abbreviations.reverse_lookup('⁻¹something something')
    )
  end)

  it('returns an empty table for non-existing abbreviations', function()
    assert.is.same(
      {},
      abbreviations.reverse_lookup(' ')
    )
  end)
end)
