# A VHS script for demoing lean.nvim's basic functionality.
#
# At the minute it depends on a few of @Julian's neovim setup tweaks (e.g. using ; rather than : for command mode).
# This in theory could be isolated, but it's more convenient to start this way as it also means we get a fully "decorated" / "usable" setup rather than the barebones neovim one gets from running with the minimal init via `just nvim`.

Require lake
Require nvim

Output demo.gif
Output demo.mp4

Set Shell "zsh"
Set FontFamily Inconsolata
Set Padding 20
Set Width 800
Set Height 500
Set FontSize 12

Type "nvim" Sleep 1s Enter
Hide Type ";luafile demos/basic.lua" Enter Show

Hide Type ";lua DEMO.popup()" Enter Show
Type "lean.nvim brings support for the Lean theorem prover to Neovim." Sleep 500ms Enter
Enter
Type "Have a look at our proof on the left and the infoview on the right." Sleep 1s
Escape Hide Type ";q!" Enter Show

Type@5ms ";e demos/project/NeovimLoves.lean" Enter Sleep 500ms

Hide
Type "iimport Mathlib.Data.Real.Irrational" Enter
Type "import Mathlib.Analysis.SpecialFunctions.Pow.Real" Enter
Enter
Sleep 20s
Show

Type@20ms "open Real in" Enter
Type@40ms "-- There exist two irrational numbers `x` and `y`" Enter
Type@40ms "-- such that `x ^ y` is rational." Enter
Type "lemma exists_pow_not_irrational :" Enter
Type "  ∃ (x y : " Sleep 500ms
Escape

Hide
Type ";lua DEMO.popup()" Enter Show
Type "Typing out unicode abbreviations works just like in VSCode..." Sleep 1s
Escape Hide Type ";q!" Enter Show

Type "i \R),"
Sleep 1s Escape

Hide
Type ";lua DEMO.popup()" Enter
Type "Typing out unicode abbreviations works just like in VSCode..." Enter
Enter Show
Type "including showing you how to type what you need." Sleep 1s
Escape Hide Type ";q!" Enter Show

Type "hhh"
Space Space Type "\\"
Sleep 2s
Escape
Type "o"

Type "  Irrational x" Enter
Type "∧ Irrational y" Enter
Type "∧ ¬ Irrational (x ^ y) := by" Enter
Type "  sorry"
Sleep 2s Escape

Hide Type ";lua DEMO.popup()" Enter Show
Type "Diagnostics appear whenever Lean sends them." Sleep 1s
Escape Hide Type ";q!" Enter Show

Type@20ms ";lua vim.diagnostic.goto_next{ float = { header = false } }" Enter Sleep 2s

Hide Type ";lua DEMO.popup()" Enter Show
Type "We can of course hover to see documentation for anything which has it." Sleep 1s
Escape Hide Type ";q!" Enter Show

Type "/Irra" Sleep 500ms Enter
Type "K" Sleep 3s

Hide Type ";lua DEMO.popup()" Enter Show
Type "Or jump to its definition." Sleep 1s
Escape Hide Type ";q!" Enter Show

Type "gd" Sleep 4s
Ctrl+o

Type "G$b" Sleep 2s

Hide Type ";lua DEMO.popup()" Enter Show
Type "Don't forget about widgets! lean.nvim certainly hasn't." Sleep 1s
Escape Hide Type ";q!" Enter Show

Ctrl+w
Type "lw" Sleep 500ms
Enter Sleep 1s
Type "wwwww"
Sleep 1s

Ctrl+w
Type "hciw"

Type "by_cases h : ¬ Irrational (sqrt 2 ^ sqrt 2)" Enter Sleep 1s

Escape Hide Type ";lua DEMO.popup()" Enter Show
Type "Code actions are executable as well." Enter
Enter
Type "Watch --" Enter
Enter
Type "here we use one to write out the `cases` tactic branches." Sleep 1s
Escape Hide Type ";q!" Enter Show

Type ";lua vim.lsp.buf.code_action()" Enter
Sleep 1s
Type "1" Enter
Sleep 2s

Type "kciw"
Type "exact ⟨sqrt 2," Enter
Space Space Space Space Space Space Space Space Space
Type "sqrt 2," Enter
Type "by sorry," Enter
Type "by sorry," Enter
Type "by sorry⟩"
Sleep 2s

Escape Hide Type ";lua DEMO.popup()" Enter Show
Type "Let's get `exact?` to help us finish this branch off." Sleep 1s
Escape Hide Type ";q!" Enter Show

Type "/sorry" Sleep 500ms Enter
Type ";Switch" Enter
Sleep 1s
Hide Sleep 30s Show

Type@25ms ";lua vim.lsp.buf.code_action()" Enter
Type "1" Enter Sleep 1s

Type "/sorry" Enter
Type ";Switch" Enter
Hide Sleep 30s Show
Type@25ms ";lua vim.lsp.buf.code_action()" Enter
Type "1" Enter Sleep 500ms

Type "/sorry" Sleep 500ms Enter
Type ";Switch" Enter
Sleep 1s
Hide Sleep 30s Show
Type ";lua vim.lsp.buf.code_action()" Enter
Type "1" Enter Sleep 500ms

Type "jciwexact ⟨sqrt 2 ^ sqrt 2," Enter
Space Space Space Space Space Space Space Space Space
Type "sqrt 2," Enter
Type "not_not.mp h," Enter
Type "irrational_sqrt_two," Enter
Type "by" Enter
Type "  rw [\l" Tab
Type "rpow_mul (sqrt_nonneg 2)]" Enter
Type "norm_num" Enter
Type "exact (2 : ℚ).not_irrational⟩" Enter
Escape

Sleep 5s

Hide Type ";lua DEMO.popup()" Enter Show
Type "This was just a taste of lean.nvim." Enter
Enter
Type "Give it a try!" Enter
Enter
Type "Even more information and functionality can be found in the README." Enter
Type "Also feel free to ask questions, or to send suggestions." Enter
Type "You can do so on the Zulip or on lean.nvim's issue tracker."
Enter
Type "Goals accomplished 🎉" Enter
Sleep 5s Escape
Type ";qa!" Enter
Sleep 500ms
