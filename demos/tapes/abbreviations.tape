# Demo: Unicode abbreviation expansion & reverse lookup
#
# Shows lean.nvim expanding \-prefixed abbreviations into unicode,
# then using reverse lookup to find how to type a symbol.

Require nvim

Output demos/output/abbreviations.gif
Output demos/output/abbreviations.mp4

Source demos/tapes/setup.tape

Hide
Type "just nvim" Enter
Sleep 3s
Source demos/tapes/helpers.tape
Type ":e demos/lean/Abbreviations.lean" Enter
Sleep 500ms
Show

# Go to end of file, start typing a definition with unicode
Type "Go" Enter
Type@50ms "def foo : \forall" Sleep 200ms Tab
Type@50ms " (x : \R" Sleep 200ms Tab
Type@50ms "), x \ne" Sleep 200ms Tab
Type@50ms " 0 \to" Sleep 200ms Tab
Type " True := by" Enter
Type "  sorry"
Sleep 1s
Escape

# Now show reverse lookup -- cursor on ∀
Type "k0f∀"
Sleep 500ms
# <LocalLeader> is \ by default, so \\ triggers reverse lookup
Type "\\\\"
Sleep 2s
Escape

# Reverse lookup on ℝ
Type "fℝ"
Sleep 500ms
Type "\\\\"
Sleep 2s
Escape

# End card
Hide
Type@0ms ":lua DEMO.end_card{' In this demo:', '', '  • \\-prefixed abbreviation expansion (e.g. \\forall \\to \\R)', '  • Reverse lookup to find how to type any symbol', '', ' See :h lean.abbreviations for more.'}" Enter
Show
Sleep 4s

Type ":qa!" Enter
Sleep 500ms
