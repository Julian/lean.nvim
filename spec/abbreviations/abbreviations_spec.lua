local helpers = require 'spec.helpers'

-- Wait some time for the abbreviation to have been expanded.
-- This is very naive, it just ensures the line contains no `\`.
local function wait_for_expansion()
  vim.wait(1000, function()
    local contents = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    return not contents:match [[\]]
  end)
end

require('lean').setup {}

describe('unicode abbreviation expansion', function()
  it(
    'autoexpands abbreviations',
    helpers.clean_buffer(function()
      helpers.insert [[\a]]
      assert.contents.are [[α]]
    end)
  )

  it(
    'can be enabled for other filetypes',
    helpers.clean_buffer(function()
      vim.cmd.edit { 'abbreviation-unittest.txt', bang = true }
      helpers.insert [[\a]]
      assert.contents.are [[\a]]
      vim.cmd.normal 'dd'

      require('lean.abbreviations').enable '*.txt'

      helpers.insert [[\a]]
      assert.contents.are [[α]]
      vim.cmd.bwipeout { bang = true }
    end)
  )

  describe('explicit triggers', function()
    it(
      'inserts a space on <Space>',
      helpers.clean_buffer(function()
        helpers.insert [[\e<Space>]]
        wait_for_expansion()
        assert.contents.are [[ε ]]
      end)
    )

    it(
      'inserts a newline on <CR>',
      helpers.clean_buffer(function()
        helpers.insert [[\e<CR>]]
        wait_for_expansion()
        assert.contents.are 'ε\n'
      end)
    )

    it(
      'inserts nothing on <Tab>',
      helpers.clean_buffer(function()
        helpers.insert [[\e<Tab>]]
        wait_for_expansion()
        assert.contents.are [[ε]]
      end)
    )

    it(
      'leaves the cursor in the right spot on <Tab>',
      helpers.clean_buffer(function()
        helpers.insert [[\<<Tab>abc]]
        wait_for_expansion()
        assert.contents.are [[⟨abc]]
      end)
    )

    it(
      'inserts nothing on <Tab> mid-line',
      helpers.clean_buffer('foo bar baz quux,', function()
        vim.cmd.normal '$'
        helpers.insert [[ \comp<Tab> spam]]
        wait_for_expansion()
        assert.contents.are [[foo bar baz quux ∘ spam,]]
      end)
    )

    it(
      'does not interfere with existing mappings',
      helpers.clean_buffer(function()
        vim.api.nvim_buf_set_keymap(
          0,
          'i',
          '<Tab>',
          '<C-o>:lua vim.b.foo = 12<CR>',
          { noremap = true }
        )
        helpers.insert [[\e<Tab>]]
        wait_for_expansion()
        assert.contents.are [[ε]]
        assert.falsy(vim.b.foo)
        helpers.insert [[<Tab>]]
        assert.contents.are [[ε]]
        assert.are.same(vim.b.foo, 12)

        vim.api.nvim_buf_del_keymap(0, 'i', '<Tab>')
      end)
    )

    it(
      'does not interfere with existing lua mappings',
      helpers.clean_buffer(function()
        vim.b.foo = 0
        local inc = function()
          vim.b.foo = vim.b.foo + 1
        end

        assert.is.equal(0, #vim.api.nvim_buf_get_keymap(0, 'i'))
        vim.keymap.set('i', '<Tab>', inc, { buffer = 0, noremap = true })
        assert.is.equal(1, #vim.api.nvim_buf_get_keymap(0, 'i'))

        assert.are.same(vim.b.foo, 0)
        helpers.insert [[<Tab>]]
        assert.are.same(vim.b.foo, 1)

        helpers.insert [[\e<Tab>]]
        wait_for_expansion()
        assert.contents.are [[ε]]
        assert.are.same(vim.b.foo, 1)
        helpers.insert [[<Tab>]]
        assert.contents.are [[ε]]
        assert.are.same(vim.b.foo, 2)
        vim.api.nvim_buf_del_keymap(0, 'i', '<Tab>')
      end)
    )
  end)

  -- Really this needs to place the cursor too, but for now we just strip
  it(
    'handles placing the $CURSOR',
    helpers.clean_buffer(function()
      helpers.insert [[foo \<><Tab>bar, baz]]
      assert.current_line.is 'foo ⟨bar, baz⟩'
    end)
  )

  it(
    'expands mid-word',
    helpers.clean_buffer(function()
      helpers.insert [[(\a]]
      assert.contents.are [[(α]]
    end)
  )

  it(
    'expands abbreviations in command mode',
    helpers.clean_buffer(function()
      helpers.insert [[foo ε bar]]
      vim.cmd.normal '$'
      helpers.feed [[q/a\e<Space><CR>ibaz]]
      assert.current_line.is 'foo bazε bar'
    end)
  )
end)
