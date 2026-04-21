# Demo: Infoview pins
#
# Shows adding pins to freeze goal state at specific locations,
# then clearing them.

Require nvim

Output demos/output/pins.gif
Output demos/output/pins.mp4

Source demos/tapes/setup.tape
Set TypingSpeed 40ms

Hide
Type "just nvim" Enter
Sleep 3s
Source demos/tapes/helpers.tape
Type ":e demos/lean/Demos/Pins.lean" Enter
Sleep 500ms
# Position on `refine` — infoview shows the full goal before it runs
Type "5G0fr"
Sleep 30s
Ctrl+l
Sleep 2s

# Intro popup
Type@0ms ":lua DEMO.hide_keys() DEMO.popup()" Enter
Sleep 500ms
Show
Type@30ms "Pins freeze the goal state at a"
Enter
Type@30ms "cursor position. They stay visible"
Enter
Type@30ms "while you move elsewhere."
Sleep 3s
Escape
Hide
Type@0ms ":lua DEMO.close_popup() DEMO.restore_keys()" Enter
Ctrl+l
Sleep 2s
Show
Sleep 2s

# Pin the goal at `refine` — shows the full conjunction goal
Type "\x"
Sleep 4s

# Move to the first sorry — infoview updates to show ⊢ p
Type "6G0fs"
Sleep 3s

# Explain what happened
Hide
Type@0ms ":lua DEMO.hide_keys() DEMO.popup()" Enter
Sleep 500ms
Show
Type@30ms "The pin shows the original goal."
Enter
Type@30ms "The infoview follows the cursor."
Sleep 3s
Escape
Hide
Type@0ms ":lua DEMO.close_popup() DEMO.restore_keys()" Enter
Ctrl+l
Sleep 2s
Show
Sleep 1s

# Move to the second sorry — infoview updates to show ⊢ q
Type "7G0fs"
Sleep 3s

# Clear all pins
Type "\c"
Sleep 3s

# End card
Hide
Type@0ms ":lua DEMO.end_card{' Infoview pins:', '', '  \\\\x         add a pin at cursor', '  \\\\c         clear all pins', '  \\\\p         pause/unpause pins', '  \\\\dx        set a diff pin', '  \\\\dc        clear diff pins', '', ' See :h lean.infoview for more.'}" Enter
Show
Sleep 4s

Type ":qa!" Enter
Sleep 500ms
