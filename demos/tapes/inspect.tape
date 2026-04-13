# Demo: Inspecting code — diagnostics, hover, go-to-definition
#
# Shows a natural workflow: write a theorem, see a warning,
# investigate with hover and go-to-definition, then fix it.

Require nvim

Output demos/output/inspect.gif
Output demos/output/inspect.mp4

Source demos/tapes/setup.tape
Set TypingSpeed 40ms

Hide
Type "just nvim" Enter
Sleep 3s
Source demos/tapes/helpers.tape
# Add a border to hover floats so they stand out
Type ":lua vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, { border = 'rounded' })" Enter
Type ":e demos/lean/Demos/Inspect.lean" Enter
Sleep 500ms
Type "gg"
Sleep 30s
Ctrl+l
Sleep 2s
Show
Sleep 2s

# Start writing a theorem about double
Type "Go" Enter
Type@40ms "theorem double_zero : double 0 = 0 := by"
Sleep 2s

# Try sorry — it works but leaves a warning
Enter
Type@40ms "sorry"
Sleep 3s
Escape

# There's a warning — jump to it
Type "]d"
Sleep 2s

# What is `double` exactly? Hover to find out.
Type "0f:w"
Sleep 500ms
Type "K"
Sleep 4s

# Jump to the definition to see the implementation
Type "gd"
Sleep 3s

# Now we know it's n + n, so rfl should work. Go back and fix.
Ctrl+o
Sleep 1s
Type "/sorry" Enter
Type@40ms "ciwrfl"
Escape
Sleep 4s

# End card
Hide
Type@0ms ":lua DEMO.end_card{' Inspecting code:', '', '  ]d / [d     next / previous diagnostic', '  K            hover documentation', '  gd           go-to-definition', '', ' See :h lean for more.'}" Enter
Show
Sleep 4s

Type ":qa!" Enter
Sleep 500ms
