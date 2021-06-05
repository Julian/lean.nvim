" This possibly belongs in lean.vim or switch.vim itself but putting it here
" for now.

if !exists("g:loaded_switch")
  finish
endif

let b:switch_definitions = [
    \ g:switch_builtins.true_false,
    \ ["#check", "#eval", "#reduce"],
    \ ['\(begin\n\s*\)\@<!sorry', 'begin\r  sorry\rend'],
    \ ["tidy", "suggest", "hint", "linarith", "library_search"],
    \ ["rw", "simp", "simp?"],
    \ ["cases", "rcases", "obtain"],
    \ ["norm_cast", "push_cast"],
    \ ["inl", "inr"],
    \ ["tt", "ff"],
    \ ["=", "≠"],
    \ ["∈", "∉"],
    \ ["∪", "∩"],
    \ ["⋃", "⋂"],
    \ ["⊆", "⊂", "⊃", "⊇"],
    \ ["Σ", "∑"],
    \ ["∀", "∃"],
    \ ["∧", "∨"],
    \ ["⊔", "⊓"],
    \ ["⊥", "⊤"],
    \ ["⋀", "⋁"],
    \ ["×", "→"],
    \ ["0", "₀", "⁰"],
    \ ["1", "₁", "¹"],
    \ ["2", "₂", "²"],
    \ ["3", "₃", "³"],
    \ ["4", "₄", "⁴"],
    \ ["5", "₅", "⁵"],
    \ ["6", "₆", "⁶"],
    \ ["7", "₇", "⁷"],
    \ ["8", "₈", "⁸"],
    \ ["9", "₉", "⁹"],
\ ]
