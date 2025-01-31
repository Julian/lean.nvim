local clean_buffer = require('spec.helpers').clean_buffer

describe('terms', function()
  it(
    'switch between left and right',
    clean_buffer([[#check Nat.mul_le_mul_right]], function()
      vim.cmd.normal { '1gg23|', bang = true }
      vim.cmd.Switch()
      assert.contents.are [[#check Nat.mul_le_mul_left]]

      vim.cmd.Switch()
      assert.contents.are [[#check Nat.mul_le_mul_right]]
    end)
  )

  it(
    'switch between mul and add',
    clean_buffer([[#check Nat.add_one]], function()
      vim.cmd.normal { '1gg13|', bang = true }
      vim.cmd.Switch()
      assert.contents.are [[#check Nat.mul_one]]

      vim.cmd.Switch()
      assert.contents.are [[#check Nat.add_one]]
    end)
  )

  it(
    'switch between zero and one',
    clean_buffer([[#check Nat.mul_one]], function()
      vim.cmd.normal { '1gg$', bang = true }
      vim.cmd.Switch()
      assert.contents.are [[#check Nat.mul_zero]]

      vim.cmd.Switch()
      assert.contents.are [[#check Nat.mul_one]]
    end)
  )

  it(
    'switch between top and bot',
    clean_buffer([[#check WithTop]], function()
      vim.cmd.normal { '1gg$', bang = true }
      vim.cmd.Switch()
      assert.contents.are [[#check WithBot]]

      vim.cmd.Switch()
      assert.contents.are [[#check WithTop]]
    end)
  )
end)

describe('tactics', function()
  it(
    'switch between exact <> and refine <>',
    clean_buffer([[exact ⟨foo, bar⟩]], function()
      vim.cmd.normal { '1gg0', bang = true }
      vim.cmd.Switch()
      assert.contents.are [[refine ⟨foo, bar⟩]]
    end)
  )

  it(
    'do not switch between exact foo and refine foo',
    clean_buffer([[exact foo]], function()
      vim.cmd.normal { '1gg0', bang = true }
      vim.cmd.Switch()
      assert.contents.are [[exact foo]]
    end)
  )

  it(
    'switch between simp only [foo] and simp',
    clean_buffer([=[simp only [foo, bar, baz]]=], function()
      vim.cmd.normal { '1gg0', bang = true }
      vim.cmd.Switch()
      assert.contents.are [[simp]]
    end)
  )

  it(
    'switch between simp and simp?',
    clean_buffer([[simp]], function()
      vim.cmd.normal { '1gg0', bang = true }
      vim.cmd.Switch()
      assert.contents.are [[simp?]]

      vim.cmd.Switch()
      assert.contents.are [[simp]]
    end)
  )

  it(
    'switch between simp [foo] and simp? [foo]',
    clean_buffer([=[simp [foo, bar, baz]]=], function()
      vim.cmd.normal { '1gg0', bang = true }
      vim.cmd.Switch()
      assert.contents.are [=[simp? [foo, bar, baz]]=]
    end)
  )

  it(
    'switch between simpa and simpa?',
    clean_buffer([[simpa]], function()
      vim.cmd.normal { '1gg0', bang = true }
      vim.cmd.Switch()
      assert.contents.are [[simpa?]]

      vim.cmd.Switch()
      assert.contents.are [[simpa]]
    end)
  )

  it(
    'switch between simp_all and simp_all?',
    clean_buffer([[simp_all]], function()
      vim.cmd.normal { '1gg0', bang = true }
      vim.cmd.Switch()
      assert.contents.are [[simp_all?]]

      vim.cmd.Switch()
      assert.contents.are [[simp_all]]
    end)
  )
end)
