import ProofWidgets.Component.Basic
import ProofWidgets.Component.HtmlDisplay

open ProofWidgets Jsx

def svgCircle : Html :=
  .element "svg"
    #[("xmlns", "http://www.w3.org/2000/svg"), ("width", "200"), ("height", "200")]
    #[.element "circle"
        #[("cx", "100"), ("cy", "100"), ("r", "80"), ("fill", "#4169E1")]
        #[]]

#html svgCircle
