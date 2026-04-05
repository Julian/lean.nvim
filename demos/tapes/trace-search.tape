# Demo: Trace search in the infoview
#
# Shows ]t/[t for trace navigation and <LocalLeader>/ to search
# through trace messages, with n/N to navigate matches.

Require nvim

Output demos/output/trace-search.gif
Output demos/output/trace-search.mp4

Source demos/tapes/setup.tape

Hide
Type "just nvim" Enter
Sleep 3s
Source demos/tapes/helpers.tape
Type ":e demos/lean/Demos/TraceSearch.lean" Enter
Sleep 500ms
Type "4G0frl"
Sleep 30s
Ctrl+l
Sleep 2s
Show
Sleep 3s

# Jump to the infoview with <LocalLeader><Tab>
Type "\"
Tab
Sleep 1s

# Navigate to a trace diagnostic with ]t
Type "]t"
Sleep 2s

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
