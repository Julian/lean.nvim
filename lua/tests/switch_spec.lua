local helpers = require('tests.helpers')
local clean_buffer = helpers.clean_buffer

require('lean').setup{}

describe('switch', function()
  it('switches between left and right',
    clean_buffer('lean3', [[#check mul_right_comm]], function()
    vim.api.nvim_command('normal! 1gg12|')
    vim.cmd('Switch')
    assert.contents.are[[#check mul_left_comm]]

    vim.cmd('Switch')
    assert.contents.are[[#check mul_right_comm]]
  end))

  it('switches between top and bot',
    clean_buffer('lean3', [[#check with_top]], function()
    vim.api.nvim_command('normal! 1gg$')
    vim.cmd('Switch')
    assert.contents.are[[#check with_bot]]

    vim.cmd('Switch')
    assert.contents.are[[#check with_top]]
  end))

  it('does not switch between top and bot prefix',
    clean_buffer('lean3', [[#check tops]], function()
    vim.api.nvim_command('normal! 1gg$hh')
    vim.cmd('Switch')
    assert.contents.are[[#check tops]]
  end))

  it('does not switch between top and bot suffix',
    clean_buffer('lean3', [[#check stop]], function()
    vim.api.nvim_command('normal! 1gg$')
    vim.cmd('Switch')
    assert.contents.are[[#check stop]]
  end))

  it('switches between mul and add',
    clean_buffer('lean3', [[#check add_one]], function()
    vim.api.nvim_command('normal! 1gg9|')
    vim.cmd('Switch')
    assert.contents.are[[#check mul_one]]

    vim.cmd('Switch')
    assert.contents.are[[#check add_one]]
  end))

  it('switches between zero and one',
    clean_buffer('lean3', [[#check mul_one]], function()
    vim.api.nvim_command('normal! 1gg$')
    vim.cmd('Switch')
    assert.contents.are[[#check mul_zero]]

    vim.cmd('Switch')
    assert.contents.are[[#check mul_one]]
  end))

  it('switches between exact <> and refine <>',
    clean_buffer('lean3', [[exact ⟨foo, bar⟩]], function()
    vim.api.nvim_command('normal! 1gg0')
    vim.cmd('Switch')
    assert.contents.are[[refine ⟨foo, bar⟩]]
  end))

  it('does not switch between exact foo and refine foo',
    clean_buffer('lean3', [[exact foo]], function()
    vim.api.nvim_command('normal! 1gg0')
    vim.cmd('Switch')
    assert.contents.are[[exact foo]]
  end))

  it('switches between simp only [foo] and simp',
    clean_buffer("lean3", [=[simp only [foo, bar, baz]]=], function()
    vim.api.nvim_command('normal! 1gg0')
    vim.cmd('Switch')
    assert.contents.are[[simp]]
  end))

  it('switches between simp and squeeze_simp',
    clean_buffer("lean3", [[simp]], function()
    vim.api.nvim_command('normal! 1gg0')
    vim.cmd('Switch')
    assert.contents.are[[squeeze_simp]]
  end))

  it('switches between simp [foo] and squeeze_simp [foo]',
    clean_buffer("lean3", [=[simp [foo, bar, baz]]=], function()
    vim.api.nvim_command('normal! 1gg0')
    vim.cmd('Switch')
    assert.contents.are[=[squeeze_simp [foo, bar, baz]]=]
  end))
end)
