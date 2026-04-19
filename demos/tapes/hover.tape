# Demo: Interactive hover popups
#
# Shows the interactive hover where subexpressions are clickable:
# press K to see a type, press it again inside the popup to drill
# deeper, press gd to jump to a definition.

Require nvim

Output demos/output/hover.gif
Output demos/output/hover.mp4

Source demos/tapes/setup.tape
Set TypingSpeed 40ms

Hide
Type "just nvim" Enter
Sleep 3s
Source demos/tapes/helpers.tape
Type ":e demos/lean/Demos/Hover.lean" Enter
Sleep 500ms
Type "gg"
Sleep 30s
Ctrl+l
Sleep 2s

# Intro popup
Type@0ms ":lua DEMO.hide_keys() DEMO.popup()" Enter
Sleep 500ms
Show
Type@30ms "Pressing K opens an interactive hover."
Enter
Type@30ms "Subexpressions are clickable —"
Enter
Type@30ms "drill into types, jump to definitions."
Sleep 3s
Escape
Hide
Type@0ms ":lua DEMO.close_popup() DEMO.restore_keys()" Enter
Ctrl+l
Sleep 2s
Show
Sleep 1s

# Hover over Nat.add to show its signature and documentation
Type "3G"
Sleep 1s
Type "f."
Sleep 500ms
Type "K"
Sleep 3s

# Close hover
Escape
Sleep 1s

# Hover over Nat.zero and click on the type
Type "5G"
Sleep 500ms
Type "fz"
Sleep 500ms
Type "K"
Sleep 2s

# Enter the hover window, move to the interactive 'Nat' type, and drill in
Type "K"
Sleep 500ms
Type "$b"
Sleep 500ms
Type "K"
Sleep 3s

Sleep 2s

# End card
Hide
Type@0ms ":only" Enter
Type@0ms ":lua DEMO.end_card{' Interactive hover:', '', '  K opens a hover with clickable subexpressions.', '  Press K or <CR> on a type to drill deeper,', '  gd to jump to its definition.'}" Enter
Show
Sleep 4s

Type ":qa!" Enter
Sleep 500ms
