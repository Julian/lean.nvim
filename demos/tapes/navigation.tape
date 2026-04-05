# Demo: Semantic navigation in the infoview
#
# Shows ]g/[g for goals, ]h/[h for hypotheses,
# and ]s/[s for suggestions.

Require nvim

Output demos/output/navigation.gif
Output demos/output/navigation.mp4

Source demos/tapes/setup.tape

Hide
Type "just nvim" Enter
Sleep 3s
Source demos/tapes/helpers.tape
Type ":e demos/lean/Demos/Navigation.lean" Enter
Sleep 500ms
# Position on `constructor` for goal/hypothesis navigation
Type "3G0fcl"
Sleep 30s
Ctrl+l
Sleep 2s

# --- Goal navigation popup ---
Type@0ms ":lua DEMO.popup{'  Goal navigation:  ]g / [g'}" Enter
Ctrl+l
Sleep 2s
Show
Sleep 2.5s
Hide
Type ":q" Enter
Ctrl+l
Sleep 2s
Show

# Enter infoview
Type "\"
Tab
Sleep 1s

Type "]g"
Sleep 2s

Type "[g"
Sleep 2s

# --- Hypothesis navigation popup ---
Hide
Type@0ms ":lua DEMO.popup{'  Hypothesis navigation:  ]h / [h'}" Enter
Ctrl+l
Sleep 2s
Show
Sleep 2.5s
Hide
Type ":q" Enter
Ctrl+l
Sleep 2s
Show

Type "gg"
Sleep 500ms

Type "]h"
Sleep 1.5s

Type "]h"
Sleep 1.5s

Type "]h"
Sleep 1.5s

Type "[h"
Sleep 1.5s

Type "[h"
Sleep 1.5s

# --- Suggestion navigation ---
# Go back to source, move to the apply? line, wait for suggestions
Hide
Type "\"
Tab
Sleep 500ms
Type "8G0fal"
Sleep 8s
Ctrl+l
Sleep 2s
# Suggestion navigation popup
Type@0ms ":lua DEMO.popup{'  Suggestion navigation:  ]s / [s'}" Enter
Ctrl+l
Sleep 2s
Show
Sleep 2.5s
Hide
Type ":q" Enter
Ctrl+l
Sleep 2s
Show

# Enter infoview, navigate to suggestion
Type "\"
Tab
Sleep 1s

Type "gg"
Sleep 500ms

Type "]s"
Sleep 2s

Type "[s"
Sleep 2s

# Back to source
Type "\"
Tab
Sleep 1s

# End card
Hide
Type@0ms ":lua DEMO.end_card{' Infoview navigation:', '', '  ]g / [g     next / previous goal', '  ]h / [h     next / previous hypothesis', '  ]s / [s     next / previous suggestion', '  ]l / [l     next / previous link', '  ]t / [t     next / previous trace diagnostic', '', ' See :h lean.infoview for more.'}" Enter
Show
Sleep 4s

Type ":qa!" Enter
Sleep 500ms
