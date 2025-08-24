# A VHS script for demoing lean.nvim's basic functionality.
#
# At the minute it depends on a few of @Julian's neovim setup tweaks (e.g. using ; rather than : for command mode).
# This eventually should be isolated so that we build it in CI.

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
Type "`lean.nvim` brings support for the Lean theorem prover to Neovim." Sleep 500ms Enter
Enter
Type "Have a look, we'll write our proof on the left and Lean's infoview will update on the right." Sleep 1s
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
Type "∃ (x y : " Sleep 500ms
Escape

Hide
Type ";lua DEMO.popup()" Enter Show
Type "Type out unicode abbreviations straight from insert mode..." Sleep 1s
Escape Hide Type ";q!" Enter Show

Type "i \R" Tab
Type "),"
Sleep 1s Escape

Hide
Type ";lua DEMO.popup()" Enter
Type "Type out unicode abbreviations straight from insert mode..." Enter
Enter Show
Type "Or ask `lean.nvim` to show you how to type what you need." Sleep 1s
Escape Hide Type ";q!" Enter Show

Type "hh"
Space Space Type "\\"
Sleep 2s
Escape
Type "o"

Type "  Irrational x" Enter
Type "∧ Irrational y" Enter
Type "∧ ¬ Irrational (x ^ y) := by" Enter
Backspace Backspace
Type "sorry"
Sleep 2s Escape

Hide Type ";lua DEMO.popup()" Enter Show
Type "You'll see error diagnostics when your proof has an issue." Sleep 1s
Escape Hide Type ";q!" Enter Show

Type@20ms "]d" Sleep 300ms
Ctrl+w
Type@20ms "d" Sleep 2s

Hide Type ";lua DEMO.popup()" Enter Show
Type "You can hover to see documentation for anything which has it." Sleep 1s
Escape Hide Type ";q!" Enter Show

Type "/Irra" Sleep 500ms Enter
Type "K" Sleep 3s

Hide Type ";lua DEMO.popup()" Enter Show
Type "Or jump to its definition to read how it's defined." Sleep 1s
Escape Hide Type ";q!" Enter Show

Type "gd" Sleep 4s
Ctrl+o

Type "G$b" Sleep 2s

Hide Type ";lua DEMO.popup()" Enter Show
Type "Don't forget about Lean widgets! `lean.nvim` certainly hasn't." Sleep 1s
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
Type "here we use one to write out the `by_cases` proof branches." Sleep 1s
Escape Hide Type ";q!" Enter Show

Type "gra"
Sleep 1s
Type "1" Enter
Sleep 2s

Type "k$ciw"
Type "exact ⟨sqrt 2," Enter
Space Space Space Space Space Space Space
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
Hide Sleep 20s Show

Type "gra"
Type "1" Enter Sleep 1s

Type "/sorry" Enter
Type ";Switch" Enter
Hide Sleep 20s Show
Type "gra"
Type "1" Enter Sleep 500ms

Type "/sorry" Sleep 500ms Enter
Type ";Switch" Enter
Sleep 1s
Hide Sleep 20s Show
Type "gra"
Type "1" Enter Sleep 500ms

Type "jciwexact ⟨sqrt 2 ^ sqrt 2," Enter
Space Space Space Space Space Space Space
Type "sqrt 2," Enter
Type "not_not.mp h," Enter
Type "irrational_sqrt_two," Enter
Type "by" Enter
Type "  rw [\l" Tab
Type "rpow_mul (sqrt_nonneg 2)]" Enter
Type "norm_num⟩"
Escape

Sleep 5s

Hide Type ";lua DEMO.popup()" Enter Show
Type "This was just a taste of `lean.nvim`." Enter
Enter
Type "Give it a try!" Enter
Enter
Type "Even more information and functionality can be found in the README and manual." Enter
Type "Feel free to ask questions or send suggestions for improvement." Enter
Type "You can do so on the Lean Zulip or on `lean.nvim`'s issue tracker."
Enter
Enter
Type "Goals accomplished 🎉"
Sleep 5s Escape
Type ";qa!" Enter
Sleep 500ms
