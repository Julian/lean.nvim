# Load shared demo helpers and show the keystroke overlay.
# Source this after nvim is open, while still hidden.

Type ":luafile demos/basic.lua" Enter
Type ":lua DEMO.show_keys()" Enter
Sleep 500ms
