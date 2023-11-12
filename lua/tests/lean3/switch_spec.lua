local clean_buffer = require('tests.lean3.helpers').clean_buffer
local if_has_lean3 = require('tests.helpers').if_has_lean3

require('lean').setup {}

if_has_lean3('switch', function()
  it(
    'switches between left and right',
    clean_buffer([[#check mul_right_comm]], function()
      vim.cmd 'normal! 1gg12|'
      vim.cmd.Switch()
      assert.contents.are [[#check mul_left_comm]]

      vim.cmd.Switch()
      assert.contents.are [[#check mul_right_comm]]
    end)
  )

  it(
    'switches between top and bot',
    clean_buffer([[#check with_top]], function()
      vim.cmd 'normal! 1gg$'
      vim.cmd.Switch()
      assert.contents.are [[#check with_bot]]

      vim.cmd.Switch()
      assert.contents.are [[#check with_top]]
    end)
  )

  it(
    'does not switch between top and bot prefix',
    clean_buffer([[#check tops]], function()
      vim.cmd 'normal! 1gg$hh'
      vim.cmd.Switch()
      assert.contents.are [[#check tops]]
    end)
  )

  it(
    'does not switch between top and bot suffix',
    clean_buffer([[#check stop]], function()
      vim.cmd 'normal! 1gg$'
      vim.cmd.Switch()
      assert.contents.are [[#check stop]]
    end)
  )

  it(
    'switches between mul and add',
    clean_buffer([[#check add_one]], function()
      vim.cmd 'normal! 1gg9|'
      vim.cmd.Switch()
      assert.contents.are [[#check mul_one]]

      vim.cmd.Switch()
      assert.contents.are [[#check add_one]]
    end)
  )

  it(
    'switches between zero and one',
    clean_buffer([[#check mul_one]], function()
      vim.cmd 'normal! 1gg$'
      vim.cmd.Switch()
      assert.contents.are [[#check mul_zero]]

      vim.cmd.Switch()
      assert.contents.are [[#check mul_one]]
    end)
  )

  it(
    'switches between exact <> and refine <>',
    clean_buffer([[exact ⟨foo, bar⟩]], function()
      vim.cmd 'normal! 1gg0'
      vim.cmd.Switch()
      assert.contents.are [[refine ⟨foo, bar⟩]]
    end)
  )

  it(
    'does not switch between exact foo and refine foo',
    clean_buffer([[exact foo]], function()
      vim.cmd 'normal! 1gg0'
      vim.cmd.Switch()
      assert.contents.are [[exact foo]]
    end)
  )

  it(
    'switches between simp only [foo] and simp',
    clean_buffer([=[simp only [foo, bar, baz]]=], function()
      vim.cmd 'normal! 1gg0'
      vim.cmd.Switch()
      assert.contents.are [[simp]]
    end)
  )

  it(
    'switches between simp and squeeze_simp',
    clean_buffer([[simp]], function()
      vim.cmd 'normal! 1gg0'
      vim.cmd.Switch()
      assert.contents.are [[squeeze_simp]]
    end)
  )

  it(
    'switches between simp [foo] and squeeze_simp [foo]',
    clean_buffer([=[simp [foo, bar, baz]]=], function()
      vim.cmd 'normal! 1gg0'
      vim.cmd.Switch()
      assert.contents.are [=[squeeze_simp [foo, bar, baz]]=]
    end)
  )
end)
