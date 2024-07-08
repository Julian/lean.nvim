def Good (n : Nat) := True

@[simp] theorem Good_zero : Good 0 := ⟨⟩
@[simp] theorem Good_succ_iff : Good (n+1) ↔ Good n := Iff.rfl

set_option trace.Meta.Tactic.simp true in
example : Good 500 := by simp
