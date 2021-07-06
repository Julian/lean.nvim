local helpers = require('tests.helpers')

helpers.setup { abbreviations = { builtin = true } }

for _, ft in pairs{"lean3", "lean"} do

describe('builtin abbreviations', function()
  describe(ft, function()
    it('autoexpands abbreviations', helpers.clean_buffer(ft, '', function()
      helpers.insert('\\a')
      assert.is.equal('α', vim.api.nvim_get_current_line())
    end))

    -- Really this needs to place the cursor too, but for now we just strip
    it('handles placing the $CURSOR', helpers.clean_buffer(ft, '', function()
      pending('Julian/lean.nvim#25', function()
        helpers.insert('foo \\<><Tab>bar, baz')
        assert.is.equal('foo ⟨bar, baz⟩', vim.api.nvim_get_current_line())
      end)
    end))

    it('expands mid-word', helpers.clean_buffer(ft, '', function()
      helpers.insert('(\\a')
      assert.is.equal('(α', vim.api.nvim_get_current_line())
    end))
  end)
end)

end
