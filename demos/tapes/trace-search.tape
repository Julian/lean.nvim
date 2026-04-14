# Demo: Trace search in the infoview
#
# Shows ]t/[t for trace navigation and <LocalLeader>/ to search
# through trace messages, with n/N to navigate matches.

Require nvim

Output demos/output/trace-search.gif
Output demos/output/trace-search.mp4

Source demos/tapes/setup.tape
Set TypingSpeed 40ms

Hide
Type "just nvim" Enter
Sleep 3s
Source demos/tapes/helpers.tape
Type ":e demos/lean/Demos/TraceSearch.lean" Enter
Sleep 500ms
Type "6G0frl"
Sleep 30s
Ctrl+l
Sleep 2s

# Intro popup (typed)
Type@0ms ":lua DEMO.hide_keys() DEMO.popup()" Enter
Sleep 500ms
Show
Type@30ms "You can search through trace output"
Enter
Type@30ms "in the infoview."
Enter
Type@30ms "First, let's jump to a trace with `]t`."
Sleep 3s
Escape
Hide
Type@0ms ":lua DEMO.close_popup() DEMO.restore_keys()" Enter
Ctrl+l
Sleep 2s
Show

# Jump to the infoview with <LocalLeader><Tab>
Type "\"
Tab
Sleep 1s

# Navigate to a trace diagnostic with ]t
Type "]t"
Sleep 2s

# Search popup (typed)
Hide
Type@0ms ":lua DEMO.hide_keys() DEMO.popup()" Enter
Sleep 500ms
Show
Type@30ms "Now press `<LocalLeader>/` to search."
Enter
Type@30ms "Matching traces are highlighted"
Enter
Type@30ms "and uncollapsed."
Enter
Type@30ms "`n` and `N` move between matches."
Sleep 3s
Escape
Hide
Type@0ms ":lua DEMO.close_popup() DEMO.restore_keys()" Enter
Ctrl+l
Sleep 2s
Show

# Search for "Nat" in the traces
Type "\/"
Sleep 1s
Type "Nat"
Sleep 500ms
Enter
Sleep 3s

# Navigate between search matches with n and N
Type "n"
Sleep 1.5s

Type "n"
Sleep 1.5s

Type "N"
Sleep 2s

# Clear the search with an empty query
Type "\/"
Sleep 1s
Enter
Sleep 3s

# Go back to the Lean source with <LocalLeader><Tab>
Type "\"
Tab
Sleep 1s

# End card
Hide
Type@0ms ":lua DEMO.end_card{' Trace search:', '', '  ]t / [t              next / previous trace diagnostic', '  <LocalLeader>/       search within trace messages', '  n / N                next / previous search match', '', '  An empty search query clears highlights.', '', ' See :h lean.infoview for more.'}" Enter
Show
Sleep 4s

Type ":qa!" Enter
Sleep 500ms
