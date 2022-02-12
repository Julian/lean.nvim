local helpers = require('tests.helpers')
local clean_buffer = helpers.clean_buffer

require('lean').setup{}

describe('switch', function()
  it('switches between left and right', clean_buffer('lean3', [[
#check mul_right_comm
]], function()
    vim.api.nvim_command('normal! 1gg12|')
    vim.cmd('Switch')
    assert.is.same('#check mul_left_comm', vim.api.nvim_get_current_line())

    vim.cmd('Switch')
    assert.is.same('#check mul_right_comm', vim.api.nvim_get_current_line())
  end))

  it('switches between top and bot', clean_buffer('lean3', [[
#check with_top
]], function()
    vim.api.nvim_command('normal! 1gg$')
    vim.cmd('Switch')
    assert.is.same('#check with_bot', vim.api.nvim_get_current_line())

    vim.cmd('Switch')
    assert.is.same('#check with_top', vim.api.nvim_get_current_line())
  end))

  it('does not switch between top and bot prefix', clean_buffer('lean3', [[
#check tops
]], function()
    vim.api.nvim_command('normal! 1gg$hh')
    vim.cmd('Switch')
    assert.is.same('#check tops', vim.api.nvim_get_current_line())
  end))

  it('does not switch between top and bot suffix', clean_buffer('lean3', [[
#check stop
]], function()
    vim.api.nvim_command('normal! 1gg$')
    vim.cmd('Switch')
    assert.is.same('#check stop', vim.api.nvim_get_current_line())
  end))

  it('switches between exact <> and refine <>', clean_buffer('lean3', [[
exact ⟨foo, bar⟩
]], function()
    vim.api.nvim_command('normal! 1gg0')
    vim.cmd('Switch')
    assert.is.same('refine ⟨foo, bar⟩', vim.api.nvim_get_current_line())
  end))

  it('does not switch between exact foo and refine foo', clean_buffer('lean3', [[
exact foo
]], function()
    vim.api.nvim_command('normal! 1gg0')
    vim.cmd('Switch')
    assert.is.same('exact foo', vim.api.nvim_get_current_line())
  end))
end)
