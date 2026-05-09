# Demo: Module hierarchy exploration
#
# Shows :LeanModuleImports and :LeanModuleImportedBy
# for navigating the module import graph.

Require nvim

Output demos/output/module-hierarchy.gif
Output demos/output/module-hierarchy.mp4

Source demos/tapes/setup.tape
Set Width 1280
Set TypingSpeed 40ms

Hide
Type "just nvim" Enter
Sleep 3s
Source demos/tapes/helpers.tape
Type ":e demos/lean/Demos/Widgets.lean" Enter
Sleep 500ms
Type "gg"
Sleep 30s
Ctrl+l
Sleep 2s

# Intro popup
Type@0ms ":lua DEMO.hide_keys() DEMO.popup()" Enter
Sleep 500ms
Show
Type@30ms "Lean tracks every module's import graph."
Enter
Type@30ms "`:LeanModuleImports` shows what this file"
Enter
Type@30ms "pulls in, lazily expanded as you explore."
Sleep 3s
Escape
Hide
Type@0ms ":lua DEMO.close_popup() DEMO.restore_keys()" Enter
Ctrl+l
Sleep 2s
Show

# Show the module imports tree (cursor lands on the first child)
Type ":LeanModuleImports" Enter
Sleep 3s

# Expand the first child to reveal its own imports
Tab
Sleep 3s

# Drop onto one of the expanded grandchildren and jump to its source
Type "j"
Sleep 1s
Type "gd"
Sleep 4s

# Imported By popup — run it from the file we just jumped to
Hide
Type@0ms ":lua DEMO.hide_keys() DEMO.popup()" Enter
Sleep 500ms
Show
Type@30ms "`:LeanModuleImportedBy` flips the arrow:"
Enter
Type@30ms "everything that pulls *this* one in."
Sleep 3s
Escape
Hide
Type@0ms ":lua DEMO.close_popup() DEMO.restore_keys()" Enter
Ctrl+l
Sleep 2s
Show

# Show the imported-by tree for Lean.Elab.Command
Type ":LeanModuleImportedBy" Enter
Sleep 4s

# Close the panel
Type ":q" Enter
Sleep 1s

# End card
Hide
Type@0ms ":lua DEMO.end_card{' Module hierarchy:', '', '  :LeanModuleImports      imports of this module', '  :LeanModuleImportedBy   importers of this module', '', '  <Tab>       toggle a node', '  <CR> or gd  open the module file', '  r           refresh', '', ' Requires Lean >= 4.22.0.'}" Enter
Show
Sleep 4s

Type ":qa!" Enter
Sleep 500ms
