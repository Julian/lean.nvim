local helpers = require('tests.helpers')

describe('abbreviations', function()
  helpers.setup { abbreviations = { snippets = true } }
  describe('expansion', function()
    describe('snippets.nvim', function()
      it('expands abbreviations', helpers.clean_buffer('', function()
        require('snippets').use_suggested_mappings(true)
        helpers.insert('\\a<C-k>')
        assert.is.equal('α', vim.api.nvim_get_current_line())
      end))

      -- Really this needs to place the cursor too, but for now we just strip
      it('handles placing the $CURSOR', helpers.clean_buffer('', function()
        require('snippets').use_suggested_mappings(true)
        helpers.insert('foo \\<><C-k>bar, baz')
        assert.is.equal('foo ⟨bar, baz⟩', vim.api.nvim_get_current_line())
      end))

      it('does not autoexpand', helpers.clean_buffer('', function()
        require('snippets').use_suggested_mappings(true)
        helpers.insert('\\a')
        assert.is.equal('\\a', vim.api.nvim_get_current_line())
      end))

      it('expands mid-word', helpers.clean_buffer('', function()
        pending('norcalli/snippets.nvim#17', function()
          require('snippets').use_suggested_mappings(true)
          helpers.insert('(\\a<C-k>')
          assert.is.equal('(α', vim.api.nvim_get_current_line())
        end)
      end))
    end)
  end)

  describe('programmatic API', function()
    it('provides access to loaded abbreviations', function()
      assert.is.equal('α', require('lean.abbreviations').load()['a'])
    end)

    it('provides reverse-lookup of loaded abbreviations', function()
      assert.is.same(
        { [2] = {'\\a', '\\Ga', '\\alpha'}},
        require('lean.abbreviations').reverse_lookup('α')
      )
    end)

    it('allows random trailing junk', function()
      assert.is.same(
        {
          [3] = { '\\^-' },
          [5] = { '\\-', '\\-1', '\\sy', '\\^-1', '\\inv' },
        },
        require('lean.abbreviations').reverse_lookup('⁻¹something something')
      )
    end)

    it('returns an empty table for non-existing abbreviations', function()
      assert.is.same(
        {},
        require('lean.abbreviations').reverse_lookup(' ')
      )
    end)
  end)
end)
