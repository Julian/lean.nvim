---@brief [[
--- Tests for matchit support.
---@brief ]]

local helpers = require 'spec.helpers'

describe('matchit', function()
  it(
    'jumps between section start and end',
    helpers.clean_buffer(
      [[
        section foo

        def f := 37

        end foo
      ]],
      function()
        vim.cmd.normal 'gg'
        assert.current_line.is 'section foo'
        vim.cmd.normal '%'
        assert.current_line.is 'end foo'
      end
    )
  )

  it(
    'jumps between anonymous sections',
    helpers.clean_buffer(
      [[
        section

        def f := 37

        end
      ]],
      function()
        vim.cmd.normal 'gg'
        assert.current_line.is 'section'
        vim.cmd.normal '%'
        assert.current_line.is 'end'
      end
    )
  )

  it(
    'jumps between namespace start and end',
    helpers.clean_buffer(
      [[
        namespace foo

        section bar

        def f := 37

        end bar

        end foo
      ]],
      function()
        vim.cmd.normal 'gg'
        assert.current_line.is 'namespace foo'
        vim.cmd.normal '%'
        assert.current_line.is 'end foo'
      end
    )
  )

  it(
    'jumps between namespaces named with french quote names',
    helpers.clean_buffer(
      [[
        namespace «1.2»

        section bar

        def f := 37

        end bar

        end «1.2»
      ]],
      function()
        vim.cmd.normal 'gg'
        assert.current_line.is 'namespace «1.2»'
        vim.cmd.normal '%'
        assert.current_line.is 'end «1.2»'
      end
    )
  )

  it(
    'jumps between if/then/else',
    helpers.clean_buffer(
      [[#eval String.append "it is " (if 1 > 2 then "yes" else "no")]],
      function()
        vim.cmd.normal '31|'
        assert.current_word.is 'if'

        vim.cmd.normal '%'
        assert.current_word.is 'then'

        vim.cmd.normal '%'
        assert.current_word.is 'else'
      end
    )
  )

  it(
    'jumps between do/return',
    helpers.clean_buffer(
      [[
        example : Nat := Id.run do
          let _ ← Id.run do return 1
          return 2
      ]],
      function()
        vim.cmd.normal '1$'
        assert.current_word.is 'do'

        vim.cmd.normal '%'
        assert.current_line.is '  return 2'

        vim.cmd.normal '%'
        assert.current_line.is 'example : Nat := Id.run do'

        vim.cmd.normal '2gg17|'
        assert.current_word.is 'do'

        vim.cmd.normal '%'
        assert.current_word.is 'return'
        assert.current_line.is '  let _ ← Id.run do return 1'
      end
    )
  )
end)
