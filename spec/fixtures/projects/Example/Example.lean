import Example.Squares

def has_term_goal : Nat := square 4

theorem has_tactic_goal : p ∨ q → q ∨ p := by
  intro h
  cases h with
  | inl h1 =>
    apply Or.inr
    exact h1
  | inr h2 =>
    apply Or.inl
    assumption

theorem has_multiple_goals (n : Nat) : n = n := by
  cases n
  rfl
  rfl

def has_multibyte_character {𝔽 : Type} : 𝔽 = 𝔽 := rfl

theorem will_be_modified : 37 = 37 := by
  exact rfl
