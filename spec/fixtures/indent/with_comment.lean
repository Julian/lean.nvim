/-- foo
  bar
  baz -/
theorem quux : 0 = 0 := by
  have : 0 = 0 := rfl
  -- some comment
  have : 1 = 1 := rfl
  rfl
