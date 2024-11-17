structure foo where

def spam := 37

def eggs : Nat × Nat where
  fst := 3
  snd := 37

def bar : foo where

structure quux where
  foo := bar

example : 2 = 2 := by
  cases 2
  · cases 2
    rfl
    rfl
  · rfl
