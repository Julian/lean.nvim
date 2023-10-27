local dedent = require('lean._util').dedent

describe('dedent', function()
  it('dedents multiline strings by their common prefix', function()
    assert.is.equal(
      dedent[[
        foo bar
        baz quux
      ]], 'foo bar\nbaz quux\n')
  end)

  it('leaves dedented lines alone', function()
    assert.is.equal('foo bar', dedent('foo bar'))
  end)

  it('dedents indented single lines', function()
    assert.is.equal('foo ', dedent(' foo '))
  end)

  it('ignores empty lines', function()
    assert.is.equal(
      '\nfoo bar\n\n\nbaz quux\n\n', dedent[[

        foo bar


        baz quux

      ]])
  end)

  it('leaves single lines with trailing whitespace alone', function()
    assert.is.equal('foo ', dedent('foo '))
  end)
end)
