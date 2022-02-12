if not vim.g.loaded_switch then return end

local function segment(word)
  return [[\(\<\|[_.]\)\zs]] .. word .. [[\ze\(\>\|[_.]\)]]
end

function _G.switch_lean_simp(original)
  if original[2] == '' then
    return 'squeeze_simp'
  else
    return 'simp'
  end
end

vim.b.switch_definitions = {
  vim.g.switch_builtins.true_false,
  { '#check', '#eval', '#reduce' },
  { [[\(begin\n\s*\|by \)\@<!sorry]], [[begin\r  sorry\rend]] },
  { 'by sorry', 'by library_search' },
  { 'tidy', 'suggest', 'hint', 'linarith', 'library_search' },
  { 'exact ⟨', 'refine ⟨' },
  { 'cases', 'rcases', 'obtain' },
  { 'norm_cast', 'push_cast' },
  vim.fn['switch#Words']{ 'tt', 'ff' },
  { '=', '≠' },
  { '∈', '∉' },
  { '∪', '∩' },
  { '⋃', '⋂' },
  { '⊆', '⊂', '⊃', '⊇' },
  { 'Σ', '∑' },
  { '∀', '∃' },
  { '∧', '∨' },
  { '⊔', '⊓' },
  { '⊥', '⊤' },
  { '⋀', '⋁' },
  { '×', '→' },
  { '0', '₀', '⁰' },
  { '1', '₁', '¹' },
  { '2', '₂', '²' },
  { '3', '₃', '³' },
  { '4', '₄', '⁴' },
  { '5', '₅', '⁵' },
  { '6', '₆', '⁶' },
  { '7', '₇', '⁷' },
  { '8', '₈', '⁸' },
  { '9', '₉', '⁹' },
  { 'ℕ', 'ℚ', 'ℝ', 'ℂ' },

  {
    [ [=[\<simp\(\s\+only\s\+\[[^\]]*]\)\?]=] ] = _G.switch_lean_simp,
    [ [=[\<squeeze_simp\(\s\+only\s\+\[[^\]]*]\)\?]=] ] = _G.switch_lean_simp,
  },

  { [ segment('bot') ] = 'top', [ segment('top') ] = 'bot' },
  { [ segment('inl') ] = 'inr', [ segment('inr') ] = 'inl' },
  { [ segment('left') ] = 'right', [ segment('right') ] = 'left' },
}
