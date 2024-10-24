local util = require 'lean._util'

describe('dedent', function()
  it('dedents multiline strings by their common prefix', function()
    assert.is.equal(
      util.dedent [[
        foo bar
        baz quux
      ]],
      'foo bar\nbaz quux\n'
    )
  end)

  it('leaves dedented lines alone', function()
    assert.is.equal('foo bar', util.dedent 'foo bar')
  end)

  it('dedents indented single lines', function()
    assert.is.equal('foo ', util.dedent ' foo ')
  end)

  it('ignores empty lines', function()
    assert.is.equal(
      '\nfoo bar\n\n\nbaz quux\n\n',
      util.dedent [[

        foo bar


        baz quux

      ]]
    )
  end)

  it('leaves single lines with trailing whitespace alone', function()
    assert.is.equal('foo ', util.dedent 'foo ')
  end)
end)

describe('subprocesses', function()
  describe('check_output', function()
    it('returns subprocess output', function()
      local stdout = util.subprocess_check_output {
        command = 'lean',
        args = { '--run', '--stdin' },
        writer = util.dedent [[
          def main : IO Unit := IO.println "Hello, world!"
        ]],
      }
      assert.are.same({ 'Hello, world!' }, stdout)
    end)

    it('errors for unsuccessful processes', function()
      local successful, error = pcall(util.subprocess_check_output, {
        command = 'lean',
        args = { '--run', '--stdin' },
        writer = util.dedent [[
            def main : IO Unit := IO.Process.exit 37
          ]],
      })
      assert.is_false(successful)
      assert.is.truthy(error:match 'exit status 37')
    end)
  end)
end)
