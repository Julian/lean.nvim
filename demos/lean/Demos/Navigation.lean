-- You can navigate between goals, hypotheses, and suggestions
-- using keyboard shortcuts in the infoview.

example (a : Nat) (b : Nat) (h : a < b) : a ≤ b ∧ a ≠ b := by
  constructor
  · sorry
  · sorry

example : 2 = 2 := by
  apply?
