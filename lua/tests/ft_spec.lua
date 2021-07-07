require('tests.helpers').setup {}
describe('filetype detection', function()
  describe('lean 3', function()
    describe('existing', function()
      it('root file',
        function(_)
          vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test.lean")
          assert.is.same("lean3", vim.bo.ft)
        end)

      it('nested file',
        function(_)
          vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/test1.lean")
          assert.is.same("lean3", vim.bo.ft)
        end)
    end)

    describe('new', function()
      it('root file',
        function(_)
          vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/foo.lean")
          assert.is.same("lean3", vim.bo.ft)
        end)

      it('nested file',
        function(_)
          vim.api.nvim_command("edit lua/tests/fixtures/example-lean3-project/test/foo.lean")
          assert.is.same("lean3", vim.bo.ft)
        end)
    end)
  end)

  describe('lean 4', function()
    describe('existing', function()
      it('root file',
        function(_)
          vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test.lean")
          assert.is.same("lean", vim.bo.ft)
        end)

      it('nested file',
        function(_)
          vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test/Test1.lean")
          assert.is.same("lean", vim.bo.ft)
        end)
    end)

    describe('new', function()
      it('root file',
        function(_)
          vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Foo.lean")
          assert.is.same("lean", vim.bo.ft)
        end)
      it('nested file',
        function(_)
          vim.api.nvim_command("edit lua/tests/fixtures/example-lean4-project/Test/Foo.lean")
          assert.is.same("lean", vim.bo.ft)
        end)
    end)
  end)
end)
