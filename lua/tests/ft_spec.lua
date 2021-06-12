describe('filetype detection', function()
  require('tests.helpers').setup {}

  it('recognizes a lean file',
    function(_)
      vim.api.nvim_command("edit test/lean/test.lean")
      assert.is.same(vim.bo.ft, "lean")
    end)
end)
