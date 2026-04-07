-- Trace search demo
set_option trace.Meta.isDefEq true in
example : (fun x : Nat => x + 1) 0 = 1 := by
  rfl
