local subprocess = require 'std.subprocess'
local dedent = require('std.text').dedent

describe('check_output', function()
  it('returns subprocess output', function()
    local stdout = subprocess.check_output({ 'lean', '--stdin', '--run' }, {
      stdin = dedent [[
        def main : IO Unit := IO.println "Hello, world!"
      ]],
    })
    assert.is.equal('Hello, world!\n', stdout)
  end)

  it('errors for unsuccessful processes', function()
    local successful, error = pcall(
      subprocess.check_output,
      { 'lean', '--stdin', '--run' },
      { stdin = dedent [[
          def main : IO Unit := IO.Process.exit 37
        ]] }
    )
    assert.is_false(successful)
    assert.is.truthy(error:match 'exit status 37')
  end)
end)
