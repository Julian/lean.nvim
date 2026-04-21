import ProofWidgets.Component.FilterDetails
import ProofWidgets.Component.HtmlDisplay

open ProofWidgets Jsx

def quickFilter : Html :=
  <FilterDetails
    summary={<b>Summary</b>}
    filtered={.text "filtered content"}
    all={.text "all content"}
    initiallyFiltered={true} />
