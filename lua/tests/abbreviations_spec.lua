local insert = require('tests.helpers').insert

describe('abbreviations', function()
  describe('expansion', function()
    vim.fn.nvim_buf_set_option(0, 'filetype', 'lean')

    it('expands \\-prefixed predefined abbreviations', function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {}) -- FIXME: setup

      insert('\\a<C-k>')
      assert.is.equal('α', vim.fn.nvim_get_current_line())
    end)

    it('does not autoexpand', function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {}) -- FIXME: setup

      insert('\\a')
      assert.is.equal('\\a', vim.fn.nvim_get_current_line())
    end)

    it('expands mid-word', function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {}) -- FIXME: setup

      pending('norcalli/snippets.nvim#17', function()

        insert('(\\a<C-k>')
        assert.is.equal('(α', vim.fn.nvim_get_current_line())
      end)
    end)
  end)

  describe('programmatic API', function()
    it('provides access to loaded abbreviations', function()
      assert.is.equal('α', require('lean.abbreviations').load()['\\a'])
    end)
  end)
end)
