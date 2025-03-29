local text = require 'std.text'

describe('dedent', function()
  it('dedents multiline strings by their common prefix', function()
    assert.is.equal(
      'foo bar\nbaz quux\n',
      text.dedent [[
        foo bar
        baz quux
      ]]
    )
  end)

  it('leaves dedented lines alone', function()
    assert.is.equal('foo bar', text.dedent 'foo bar')
  end)

  it('dedents indented single lines', function()
    assert.is.equal('foo ', text.dedent ' foo ')
  end)

  it('ignores empty lines', function()
    assert.is.equal(
      '\nfoo bar\n\n\nbaz quux\n\n',
      text.dedent [[

        foo bar


        baz quux

      ]]
    )
  end)

  it('also considers the first line indent', function()
    assert.is.equal(
      'foo\n  bar\n  baz\n',
      text.dedent [[
        foo
          bar
          baz
      ]]
    )
  end)

  it('leaves single lines with trailing whitespace alone', function()
    assert.is.equal('foo ', text.dedent 'foo ')
  end)
end)
