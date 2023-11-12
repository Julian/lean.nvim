local trythis = require 'lean.lean3.trythis'

local helpers = require 'tests.helpers'
local clean_buffer = require('tests.lean3.helpers').clean_buffer

require('lean').setup {}

helpers.if_has_lean3('trythis', function()
  it(
    'replaces a single try this',
    clean_buffer(
      [[
        meta def whatshouldIdo := (do tactic.trace "Try this: existsi 2; refl\n")
        example : ∃ n, n = 2 := by whatshouldIdo
      ]],
      function()
        vim.cmd.normal 'G$'
        helpers.wait_for_line_diagnostics()

        trythis.swap()
        assert.current_line.is 'example : ∃ n, n = 2 := by existsi 2; refl'
      end
    )
  )

  it(
    'replaces a single try this from by',
    clean_buffer(
      [[
        meta def whatshouldIdo := (do tactic.trace "Try this: existsi 2; refl\n")
        example : ∃ n, n = 2 := by whatshouldIdo
      ]],
      function()
        vim.cmd.normal 'G$bb'
        assert.current_word.is 'by'
        helpers.wait_for_line_diagnostics()

        trythis.swap()
        assert.current_line.is 'example : ∃ n, n = 2 := by existsi 2; refl'
      end
    )
  )

  it(
    'replaces a single try this from earlier in the line',
    clean_buffer(
      [[
        meta def whatshouldIdo := (do tactic.trace "Try this: existsi 2; refl\n")
        example : ∃ n, n = 2 := by whatshouldIdo
      ]],
      function()
        vim.cmd.normal 'G0'
        helpers.wait_for_line_diagnostics()

        trythis.swap()
        assert.current_line.is 'example : ∃ n, n = 2 := by existsi 2; refl'
      end
    )
  )

  it(
    'replaces a try this with even more unicode',
    clean_buffer(
      [[
        meta def whatshouldIdo := (do tactic.trace "Try this: existsi 0; intro m; refl")
        example : ∃ n : nat, ∀ m : nat, m = m := by whatshouldIdo
      ]],
      function()
        vim.cmd.normal 'G$'
        helpers.wait_for_line_diagnostics()

        trythis.swap()
        assert.current_line.is 'example : ∃ n : nat, ∀ m : nat, m = m := by existsi 0; intro m; refl'
      end
    )
  )

  -- Emitted by e.g. hint
  -- luacheck: ignore
  it(
    'replaces squashed together try this messages',
    clean_buffer(
      [[
        meta def whatshouldIdo := (do tactic.trace "the following tactics solve the goal\n---\nTry this: finish\nTry this: tauto\n")
        example : ∃ n, n = 2 := by whatshouldIdo
      ]],
      function()
        vim.cmd.normal 'G$'
        helpers.wait_for_line_diagnostics()

        trythis.swap()
        assert.current_line.is 'example : ∃ n, n = 2 := by finish'
      end
    )
  )

  -- Emitted by e.g. pretty_cases
  it(
    'replaces multiline try this messages',
    clean_buffer(
      [[
        meta def whatshouldIdo := (do tactic.trace "Try this: existsi 2,\n  refl,\n")
        example : ∃ n, n = 2 := by {
          whatshouldIdo
        }
      ]],
      function()
        vim.cmd.normal '3gg$'
        helpers.wait_for_line_diagnostics()

        trythis.swap()
        assert.contents.are [[
          meta def whatshouldIdo := (do tactic.trace "Try this: existsi 2,\n  refl,\n")
          example : ∃ n, n = 2 := by {
            existsi 2,
            refl,
          }]]
      end
    )
  )

  -- Emitted by e.g. library_search
  it(
    'trims by exact foo to just foo',
    clean_buffer(
      [[
        meta def whatshouldIdo := (do tactic.trace "Try this: exact rfl")
        example {n : nat} : n = n := by whatshouldIdo
      ]],
      function()
        vim.cmd.normal 'G$'
        helpers.wait_for_line_diagnostics()

        trythis.swap()
        assert.current_line.is 'example {n : nat} : n = n := rfl'
      end
    )
  )

  -- Also emitted by e.g. library_search
  it(
    'trims by exact foo to just foo',
    clean_buffer(
      [[
        meta def whatshouldIdo := (do tactic.trace "Try this: exact rfl")
        structure foo :=
        (bar (n : nat) : n = n)
        example : foo := ⟨by whatshouldIdo⟩
      ]],
      function()
        vim.cmd.normal 'G$h'
        helpers.wait_for_line_diagnostics()

        trythis.swap()
        assert.current_line.is 'example : foo := ⟨rfl⟩'
      end
    )
  )

  -- A line containing `squeeze_simp at bar` will re-suggest `at bar`, so
  -- ensure it doesn't appear twice
  it(
    'trims simp at foo when it will be duplicated',
    clean_buffer(
      [[
        meta def whatshouldIdo := (do tactic.trace "Try this: simp [foo] at bar")
        example {n : nat} : n = n := by whatshouldIdo at bar
      ]],
      function()
        vim.cmd.normal 'G$'
        helpers.wait_for_line_diagnostics()

        trythis.swap()
        assert.current_line.is 'example {n : nat} : n = n := by simp [foo] at bar'
      end
    )
  )

  -- Handle `squeeze_simp [foo]` similarly.
  it(
    'trims simp [foo] when it will be duplicated',
    clean_buffer(
      [[
        meta def whatshouldIdo (L : list name) := (do tactic.trace "Try this: simp [foo, baz]")
        example {n : nat} : n = n := by whatshouldIdo [`nat]
      ]],
      function()
        vim.cmd.normal 'G$'
        helpers.wait_for_line_diagnostics()

        trythis.swap()
        assert.current_line.is 'example {n : nat} : n = n := by simp [foo, baz]'
      end
    )
  )

  -- Handle `squeeze_simp [foo] at bar` similarly.
  it(
    'trims simp [foo] at bar when it will be duplicated',
    clean_buffer(
      [[
        meta def whatshouldIdo (L : list name) := (do tactic.trace "Try this: simp [foo, baz] at bar")
        example {n : nat} : n = n := by whatshouldIdo [`nat] at bar
      ]],
      function()
        vim.cmd.normal 'G$'
        helpers.wait_for_line_diagnostics()

        trythis.swap()
        assert.current_line.is 'example {n : nat} : n = n := by simp [foo, baz] at bar'
      end
    )
  )

  -- Handle `squeeze_simp [foo] at *` similarly.
  it(
    'trims simp [foo] at * when it will be duplicated',
    clean_buffer(
      [[
        meta def whatshouldIdo (L : list name) := (do tactic.trace "Try this: simp [foo, baz] at *")
        example {n : nat} : n = n := by whatshouldIdo [`nat] at *
      ]],
      function()
        vim.cmd.normal 'G$'
        helpers.wait_for_line_diagnostics()

        trythis.swap()
        assert.current_line.is 'example {n : nat} : n = n := by simp [foo, baz] at *'
      end
    )
  )

  it(
    'replaces squashed suggestions from earlier in the line',
    clean_buffer(
      [[
        meta def whatshouldIdo := (do tactic.trace "Try this: exact rfl")
        example {n : nat} : n = n := by whatshouldIdo
      ]],
      function()
        vim.cmd.normal 'G0'
        helpers.wait_for_line_diagnostics()

        trythis.swap()
        assert.current_line.is 'example {n : nat} : n = n := rfl'
      end
    )
  )

  -- Emitted by e.g. show_term
  it(
    'replaces redundant brace-delimited term and tactic mode',
    clean_buffer(
      [[
        meta def tactic.interactive.foo (t: tactic.interactive.itactic) : tactic.interactive.itactic :=
          (do tactic.trace "Try this: exact λ x y hxy, hf (hg hxy)\n")

        example {X Y Z : Type} {f : X → Y} {g : Y → Z} (hf : function.injective f) (hg : function.injective g) : function.injective (g ∘ f) :=
        begin
          foo {
            intros x y hxy,
            apply hf,
            apply hg,
            apply hxy,
          }
        end
      ]],
      function()
        vim.cmd.normal '6gg3|'
        helpers.wait_for_line_diagnostics()

        trythis.swap()

        -- FIXME: With a bit more tweaking this should really trim the begin/exact/end
        assert.contents.are [[
          meta def tactic.interactive.foo (t: tactic.interactive.itactic) : tactic.interactive.itactic :=
            (do tactic.trace "Try this: exact λ x y hxy, hf (hg hxy)\n")

          example {X Y Z : Type} {f : X → Y} {g : Y → Z} (hf : function.injective f) (hg : function.injective g) : function.injective (g ∘ f) :=
          begin
            exact λ x y hxy, hf (hg hxy)
          end
        ]]
      end
    )
  )

  it(
    'handles suggestions with quotes',
    clean_buffer(
      [[
        meta def whatshouldIdo := (do tactic.trace "Try this: \"hi")
        example : true := by whatshouldIdo
      ]],
      function()
        vim.cmd.normal 'G$'
        helpers.wait_for_line_diagnostics()

        trythis.swap()
        assert.current_line.is 'example : true := by "hi'
      end
    )
  )
end)
