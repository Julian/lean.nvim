import Test.Lsp

def foo : 5 = 5 := by
  have : 1 = 1 := rfl
  have : 2 = 2 := rfl
  have : 3 = 3 := rfl
  have : 4 = 4 := rfl
  rfl

def bar := 12
