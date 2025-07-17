local fixtures = require 'spec.fixtures'
local helpers = require 'spec.helpers'

vim.o.debug = 'throw'
vim.o.report = 9999

describe('indent', function()
  it(
    'indents after where',
    helpers.clean_buffer([[structure foo where]], function()
      helpers.feed 'Gofoo := 12'
      assert.current_line.is '  foo := 12'
    end)
  )

  it(
    'maintains indentation level for fields',
    helpers.clean_buffer(
      [[
      structure foo where
        foo := 12
    ]],
      function()
        helpers.feed 'Gobar := 37'
        assert.current_line.is '  bar := 37'
      end
    )
  )

  it(
    'aligns with focus dots',
    helpers.clean_buffer(
      [[
      example {n : Nat} : n = n := by
        cases n
        · have : 0 = 0 := rfl
    ]],
      function()
        helpers.feed 'Gorfl'
        assert.current_line.is '    rfl'
      end
    )
  )

  it(
    'indents after by',
    helpers.clean_buffer([[example : 2 = 2 := by]], function()
      helpers.feed 'Gorfl'
      assert.current_line.is '  rfl'
    end)
  )

  it(
    'indents after nested by',
    helpers.clean_buffer(
      [[
        example : 37 = 37 := by
          have : ∀ x : ℕ, 37 = 37 := by
     ]],
      function()
        helpers.feed 'Gorfl'
        assert.contents.are [[
        example : 37 = 37 := by
          have : ∀ x : ℕ, 37 = 37 := by
            rfl
        ]]
      end
    )
  )

  it(
    'indents after =>',
    helpers.clean_buffer(
      [[
        example {n : Nat} : n = n := by
          induction n with
          | zero =>
      ]],
      function()
        helpers.feed 'Gorfl'
        assert.contents.are [[
          example {n : Nat} : n = n := by
            induction n with
            | zero =>
              rfl
        ]]
      end
    )
  )

  it(
    'indents after =',
    helpers.clean_buffer(
      [[
        example :
            2 =
      ]],
      function()
        helpers.feed 'Goif true then 2 else 2 := rfl'
        assert.contents.are [[
          example :
              2 =
                if true then 2 else 2 := rfl
        ]]
      end
    )
  )

  it(
    'respects shiftwidth',
    helpers.clean_buffer([[structure foo where]], function()
      vim.bo.shiftwidth = 7
      helpers.feed 'Gofoo := 12'
      assert.current_line.is '       foo := 12'
    end)
  )

  it(
    'does not misindent the structure line itself',
    helpers.clean_buffer([[structure foo where]], function()
      vim.cmd.normal '=='
      assert.current_line.is 'structure foo where'
    end)
  )

  it(
    'dedents after sorry',
    helpers.clean_buffer(
      [[
        example : 37 = 37 ∧ 73 = 73 := by
          sorry
      ]],
      function()
        helpers.feed 'Go#check 37'
        assert.contents.are [[
          example : 37 = 37 ∧ 73 = 73 := by
            sorry
          #check 37
      ]]
      end
    )
  )

  it(
    'is not confused by sorry with other things on the line',
    helpers.clean_buffer(
      [[
        example : 37 = 37 := by
          have : ∀ x : ℕ, 37 = 37 := sorry
     ]],
      function()
        helpers.feed 'Gorfl'
        assert.contents.are [[
          example : 37 = 37 := by
            have : ∀ x : ℕ, 37 = 37 := sorry
            rfl
      ]]
      end
    )
  )

  it(
    'is not confused by sorry after from',
    helpers.clean_buffer(
      [[
        example : 37 = 37 := by
          suffices h : 73 = 73 from sorry
     ]],
      function()
        helpers.feed 'Gorfl'
        assert.contents.are [[
          example : 37 = 37 := by
            suffices h : 73 = 73 from sorry
            rfl
      ]]
      end
    )
  )

  it(
    'dedents after focused sorry',
    helpers.clean_buffer(
      [[
        example : 37 = 37 ∧ 73 = 73 := by
          constructor
          · sorry
      ]],
      function()
        helpers.feed 'Go· sorry'
        assert.contents.are [[
          example : 37 = 37 ∧ 73 = 73 := by
            constructor
            · sorry
            · sorry
      ]]
      end
    )
  )

  it(
    'dedents after double indented type',
    helpers.clean_buffer([[example :]], function()
      helpers.feed 'o2 = 2 :=<CR>rfl'
      assert.contents.are [[
        example :
            2 = 2 :=
          rfl
      ]]
    end)
  )

  it(
    'indents inside anonymous literals',
    helpers.clean_buffer(
      [[
        example : 2 = 2 ∧ 3 = 3 := by
          exact ⟨rfl,
      ]],
      function()
        helpers.feed 'Gorfl⟩'
        assert.contents.are [[
          example : 2 = 2 ∧ 3 = 3 := by
            exact ⟨rfl,
              rfl⟩
        ]]
      end
    )
  )

  it(
    'does not indent after blank lines with no indent below',
    helpers.clean_buffer(
      [[
        theorem foo : 37 = 37 := by
          rfl

      ]],
      function()
        helpers.feed 'G'
        assert.current_line.is ''

        helpers.feed 'o#check 37'
        assert.contents.are [[
          theorem foo : 37 = 37 := by
            rfl

          #check 37
      ]]
      end
    )
  )

  it(
    'does indent after blank lines with indent below',
    helpers.clean_buffer(
      [[
        theorem foo : 37 = 37 := by
          have : 1 = 1 := rfl

          have : 38 = 38 := rfl
      ]],
      function()
        helpers.feed 'GOhave : 37 = 37 := rfl'
        assert.contents.are [[
          theorem foo : 37 = 37 := by
            have : 1 = 1 := rfl

            have : 37 = 37 := rfl
            have : 38 = 38 := rfl
      ]]
      end
    )
  )

  it(
    'does not indent after blank lines with #commands',
    helpers.clean_buffer(
      [[
        example : True :=
          trivial

        example : 37 = 37 :=
          rfl
      ]],
      function()
        helpers.search 'trivial'
        helpers.feed 'j'
        assert.current_line.is ''
        helpers.insert '#check Nat'
        assert.contents.are [[
          example : True :=
            trivial
          #check Nat
          example : 37 = 37 :=
            rfl
        ]]
      end
    )
  )

  it(
    'indents again after by at focused stuff',
    helpers.clean_buffer(
      [[
        theorem foo : 37 = 37 := by
          · have : 37 = 37 := by
      ]],
      function()
        helpers.feed 'Gosorry'
        assert.contents.are [[
          theorem foo : 37 = 37 := by
            · have : 37 = 37 := by
                sorry
      ]]
      end
    )
  )

  for each in fixtures.indent() do
    it(each.description, function()
      vim.cmd.edit { each.unindented, bang = true }
      vim.cmd.normal 'gg=G'
      assert.are.same(each.expected, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)
  end
end)
