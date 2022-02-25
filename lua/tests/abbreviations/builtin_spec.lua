local helpers = require('tests.helpers')

-- Wait some time for the abbreviation to have been expanded.
-- This is very naive, it just ensures the line contains no `\`.
local function wait_for_expansion()
  vim.wait(1000, function()
    local contents = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    return not contents:match[[\]]
  end)
end

require('lean').setup { abbreviations = { builtin = true } }

for _, ft in pairs{'lean3', 'lean'} do

describe('builtin abbreviations', function()
  describe(ft, function()
    it('autoexpands abbreviations', helpers.clean_buffer(ft, '', function()
      helpers.insert[[\a]]
      assert.contents.are[[α]]
    end))

    describe('explicit triggers', function()
      it('inserts a space on <Space>', helpers.clean_buffer(ft, '', function()
        helpers.insert[[\e<Space>]]
        wait_for_expansion()
        assert.contents.are[[ε ]]
      end))

      it('inserts a newline on <CR>', helpers.clean_buffer(ft, '', function()
        helpers.insert[[\e<CR>]]
        wait_for_expansion()
        assert.contents.are('ε\n')
      end))

      it('inserts nothing on <Tab>', helpers.clean_buffer(ft, '', function()
        helpers.insert[[\e<Tab>]]
        wait_for_expansion()
        assert.contents.are[[ε]]
      end))

      it('leaves the cursor in the right spot on <Tab>', helpers.clean_buffer(ft, '', function()
        helpers.insert[[\<<Tab>abc]]
        wait_for_expansion()
        assert.contents.are[[⟨abc]]
      end))

      it('inserts nothing on <Tab> mid-line', helpers.clean_buffer(ft, 'foo bar baz quux,', function()
        vim.cmd('normal $')
        helpers.insert[[ \comp<Tab> spam]]
        wait_for_expansion()
        assert.contents.are[[foo bar baz quux ∘ spam,]]
      end))

      it('does not interfere with existing mappings', helpers.clean_buffer(ft, '', function()
        vim.api.nvim_buf_set_keymap(
            0,
            'i',
            '<Tab>',
            '<C-o>:lua vim.b.foo = 12<CR>',
            { noremap = true }
        )
        helpers.insert[[\e<Tab>]]
        wait_for_expansion()
        assert.contents.are[[ε]]
        assert.falsy(vim.b.foo)
        helpers.insert[[<Tab>]]
        assert.contents.are[[ε]]
        assert.are.same(vim.b.foo, 12)
        vim.api.nvim_buf_del_keymap(0, 'i', '<Tab>')
      end))
    end)

    -- Really this needs to place the cursor too, but for now we just strip
    pending('handles placing the $CURSOR', helpers.clean_buffer(ft, '', function()
      helpers.insert[[foo \<><Tab>bar, baz]]
      assert.is.equal('foo ⟨bar, baz⟩', vim.api.nvim_get_current_line())
    end))

    it('expands mid-word', helpers.clean_buffer(ft, '', function()
      helpers.insert[[(\a]]
      assert.contents.are[[(α]]
    end))
  end)
end)

end
