-- Trace output can be searched directly in the infoview.
-- Place your cursor on a trace and press <LocalLeader>/ to search.

set_option trace.Meta.isDefEq true in
example : (fun x : Nat => x + 1) 0 = 1 := by
  rfl
