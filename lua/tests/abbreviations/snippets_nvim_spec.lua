local helpers = require('tests.helpers')

require('lean').setup { abbreviations = { snippets = true } }

for _, ft in pairs{"lean3", "lean"} do

describe('snippets.nvim abbreviations', function()
  describe(ft, function()
    it('expands abbreviations', helpers.clean_buffer(ft, '', function()
      require('snippets').use_suggested_mappings(true)
      helpers.insert('\\a<C-k>')
      assert.is.equal('α', vim.api.nvim_get_current_line())
    end))

    -- Really this needs to place the cursor too, but for now we just strip
    it('handles placing the $CURSOR', helpers.clean_buffer(ft, '', function()
      require('snippets').use_suggested_mappings(true)
      helpers.insert('foo \\<><C-k>bar, baz')
      assert.is.equal('foo ⟨bar, baz⟩', vim.api.nvim_get_current_line())
    end))

    it('does not autoexpand', helpers.clean_buffer(ft, '', function()
      require('snippets').use_suggested_mappings(true)
      helpers.insert('\\a')
      assert.is.equal('\\a', vim.api.nvim_get_current_line())
    end))

    it('expands mid-word', helpers.clean_buffer(ft, '', function()
      pending('norcalli/snippets.nvim#17', function()
        require('snippets').use_suggested_mappings(true)
        helpers.insert('(\\a<C-k>')
        assert.is.equal('(α', vim.api.nvim_get_current_line())
      end)
    end))
  end)
end)

end
