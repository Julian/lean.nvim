-- Lean diagnostics can span multiple lines.
-- When they do, lean.nvim shows guide characters in the sign column
-- so you can see exactly which lines are covered.

example : Nat :=
  (1 +
   2 +
   "hello")

-- Each diagnostic above gets guide characters showing its full range,
-- rather than just marking the first line.

theorem oops (n : Nat) : n = n + 1 := by
  omega
