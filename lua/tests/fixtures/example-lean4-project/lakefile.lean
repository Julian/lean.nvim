import Lake
open Lake DSL

package Test {
  defaultFacet := PackageFacet.oleans,
  dependencies := #[{
    name := `foo
    src := Source.path ("foo")
  }]
}
