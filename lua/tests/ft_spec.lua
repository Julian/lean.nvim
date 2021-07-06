require('tests.helpers').setup {}
describe('filetype detection', function()
  it('recognizes a lean 3 file',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")
      assert.is.same("lean3", vim.bo.ft)
    end)

  it('recognizes a new lean 3 file',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/foo.lean")
      assert.is.same("lean3", vim.bo.ft)
    end)

  it('recognizes a lean 4 file',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test.lean")
      assert.is.same("lean", vim.bo.ft)
    end)

  it('recognizes a new lean 4 file',
    function(_)
      vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Foo.lean")
      assert.is.same("lean", vim.bo.ft)
    end)
end)
