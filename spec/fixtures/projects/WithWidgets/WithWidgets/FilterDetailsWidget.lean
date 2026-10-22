import ProofWidgets.Component.FilterDetails
import ProofWidgets.Component.HtmlDisplay

open ProofWidgets Jsx

def quickFilter : ProofWidgets.Html :=
  <FilterDetails
    summary={<b>Summary</b>}
    filtered={.text "filtered content"}
    all={.text "all content"}
    initiallyFiltered={true} />

def quickFilterAll : ProofWidgets.Html :=
  <FilterDetails
    summary={<b>Summary</b>}
    filtered={.text "filtered content"}
    all={.text "all content"}
    initiallyFiltered={false} />

def quickMultipleFilters : ProofWidgets.Html :=
  <span>
    <FilterDetails
      summary={<b>First</b>}
      filtered={.text "first filtered"}
      all={.text "first all"}
      initiallyFiltered={true} />
    <FilterDetails
      summary={<b>Second</b>}
      filtered={.text "second filtered"}
      all={.text "second all"}
      initiallyFiltered={true} />
  </span>
