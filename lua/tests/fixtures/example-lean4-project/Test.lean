import Test.Squares

def test1 : Nat := square 4

theorem has_tactic_goal : p ∨ q → q ∨ p := by
  intro h
  cases h with
  | inl h1 =>
    apply Or.inr
    exact h1
  | inr h2 =>
    apply Or.inl
    assumption

def new_test : Bool := by
  exact false

def utf_test {𝔽 : Type} : 𝔽 = 𝔽 := rfl
