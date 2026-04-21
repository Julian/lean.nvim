import ProofWidgets.Component.HtmlDisplay

open ProofWidgets Jsx

def quickPre : Html :=
  <span>
    <pre>{.text "hello\n  indented\n    world"}</pre>
    {.text "hello\n  indented\n    world"}
  </span>
