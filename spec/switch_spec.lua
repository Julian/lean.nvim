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
    'switch between rw [foo] and rw [← foo]',
    clean_buffer([=[rw [foo]]=], function()
      vim.cmd.normal { '1gg5|', bang = true }
      vim.cmd.Switch()
      assert.contents.are [=[rw [← foo]]=]
    end)
  )

  it(
    'switch between rw [← foo] and rw [foo]',
    clean_buffer([=[rw [← foo]]=], function()
      vim.cmd.normal { '1gg5|', bang = true }
      vim.cmd.Switch()
      assert.contents.are [=[rw [foo]]=]
    end)
  )

  it(
    'switch between rw [foo, bar] and rw [← foo, bar]',
    clean_buffer([=[rw [foo, bar]]=], function()
      vim.cmd.normal { '1gg5|', bang = true }
      vim.cmd.Switch()
      assert.contents.are [=[rw [← foo, bar]]=]
    end)
  )

  it(
    'switch between rw [foo, bar, baz] and rw [foo, ← bar, baz]',
    clean_buffer([=[rw [foo, bar, baz]]=], function()
      vim.cmd.normal { '1gg11|', bang = true }

      vim.cmd.Switch()
      assert.contents.are [=[rw [foo, ← bar, baz]]=]

      vim.cmd.Switch()
      assert.contents.are [=[rw [foo, bar, baz]]=]

      vim.cmd.normal { '1gg16|', bang = true }
      assert.contents.are [=[rw [foo, bar, ← baz]]=]
    end)
  )

  it(
    'switch between rw [foo, bar] and rw [foo, ← bar]',
    clean_buffer([=[rw [foo, bar]]=], function()
      vim.cmd.normal { '1gg11|', bang = true }
      vim.cmd.Switch()
      assert.contents.are [=[rw [foo, ← bar]]=]
    end)
  )

  it(
    'switch between rw [foo _ bar, baz] and rw [← foo _ bar, baz]',
    clean_buffer([=[rw [foo _ bar, baz]]=], function()
      vim.cmd.normal { '1gg5|', bang = true }
      vim.cmd.Switch()
      assert.contents.are [=[rw [← foo _ bar, baz]]=]
    end)
  )
end)
