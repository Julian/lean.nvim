import ProofWidgets.Component.Basic
import ProofWidgets.Component.HtmlDisplay

open ProofWidgets Jsx

/-- Demonstrates the HTML rendering features available in lean.nvim. -/
def htmlDemo : Html :=
  <div>
    <h1>HTML Rendering Demo</h1>

    <h2>Text Formatting</h2>
    <p>
      This has <b>bold</b>, <i>italic</i>, <strong>strong</strong>,
      <em>emphasized</em>, and <code>inline code</code> text.
    </p>

    <h2>Links</h2>
    <p>
      Visit the <a href="https://leanprover.github.io/">Lean website</a> for more.
    </p>

    <h2>Styled Text</h2>
    <span style={json% {"color": "green"}}>green text</span>
    {.text " and "}
    <span style={json% {"color": "red", "fontWeight": "bold"}}>red bold text</span>

    <h2>Lists</h2>
    <ul>
      <li>First item</li>
      <li>Second item with a nested list:
        <ul>
          <li>Nested item one</li>
          <li>Nested item two</li>
        </ul>
      </li>
      <li>Third item</li>
    </ul>

    <h3>Ordered</h3>
    <ol>
      <li>Step one</li>
      <li>Step two</li>
      <li>Step three</li>
    </ol>

    <hr />

    <h2>Collapsible Section</h2>
    {.element "details" #[("open", true)] #[
      .element "summary" #[] #[.text "Click to collapse"],
      .element "p" #[] #[.text "This content is hidden until the summary is clicked."],
      .element "p" #[] #[.text "It can contain "],
      .element "b" #[] #[.text "any"],
      .text " nested HTML."
    ]}

    <h2>Table</h2>
    <table>
      <thead>
        <tr>
          <th>Tactic</th>
          <th>Description</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><code>simp</code></td>
          <td>Simplify the goal</td>
        </tr>
        <tr>
          <td><code>ring</code></td>
          <td>Prove ring equalities</td>
        </tr>
        <tr>
          <td><code>omega</code></td>
          <td>Linear arithmetic</td>
        </tr>
      </tbody>
    </table>

    <h2>Preformatted</h2>
    <pre>{.text "def hello :=\n  \"world\""}</pre>
  </div>

#html htmlDemo
