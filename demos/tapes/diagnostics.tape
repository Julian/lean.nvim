# Demo: Diagnostic signs in the sign column
#
# Shows the guide characters that appear in the sign column
# when Lean reports a diagnostic whose full range spans multiple lines.

Require nvim

Output demos/output/diagnostics.gif
Output demos/output/diagnostics.mp4

Source demos/tapes/setup.tape
Set TypingSpeed 40ms

Hide
Type "just nvim" Enter
Sleep 3s
Source demos/tapes/helpers.tape
Type ":e demos/lean/Demos/Diagnostics.lean" Enter
Sleep 500ms
Type "gg"
Sleep 30s
Ctrl+l
Sleep 2s

# Intro popup — typed so the viewer reads along
Type@0ms ":lua DEMO.hide_keys() DEMO.popup()" Enter
Sleep 500ms
Show
Type@30ms "Notice the sign column on the left."
Enter
Type@30ms "When a diagnostic spans multiple lines,"
Enter
Type@30ms "lean.nvim draws guide characters"
Enter
Type@30ms "to show its full range."
Sleep 3s
Escape
Hide
Type@0ms ":lua DEMO.close_popup() DEMO.restore_keys()" Enter
Ctrl+l
Sleep 2s
Show
Sleep 1s

# Move to the first line with a sign to draw attention
Type "5G"
Sleep 2s

# Slowly scroll through the guide characters
Type "j"
Sleep 1.5s
Type "j"
Sleep 1.5s
Type "j"
Sleep 1.5s

# Pause to let the viewer see the pattern
Sleep 2s

# Move to the second error
Type "13G"
Sleep 2s
Type "j"
Sleep 1.5s

Sleep 2s

# End card
Hide
Type@0ms ":lua DEMO.end_card{' Diagnostic signs:', '', '  Guide characters in the sign column show', '  the full range of multi-line diagnostics.', '', ' See :h lean.diagnostics for more.'}" Enter
Show
Sleep 4s

Type ":qa!" Enter
Sleep 500ms
