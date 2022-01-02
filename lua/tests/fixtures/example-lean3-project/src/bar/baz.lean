import foo

def has_term_goal : nat := test

theorem has_tactic_goal {p : Prop} {q : Prop} : p ∨ q → q ∨ p :=
begin
  intro h,
  cases h with h1 h2,
    apply or.inr,
    exact h1,
    apply or.inl,
    assumption,
end

def new_test : bool := by
  exact false

theorem has_multiple_goals (n : nat) : n = n := begin
  cases n,
  refl,
  refl,
end

def has_multibyte_character {𝔽 : Type} : 𝔽 = 𝔽 := rfl
