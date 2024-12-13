instance : ToString String :=
  inferInstance
instance : ToString String :=
  inferInstance
structure foo where
structure bar where
attribute [instance] foo

@[deprecated "Bar Baz"]
structure baz where
  foo := 37
@[deprecated "Bar Baz"]
structure quux where
  foo := 37
