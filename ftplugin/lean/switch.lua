if not vim.g.loaded_switch then
  return
end

local function segment(word)
  return [[\(\<\|[_.']\)\zs]] .. word .. [[\ze\(\>\|[_.']\)]]
end

vim.b.switch_definitions = {
  vim.g.switch_builtins.true_false,
  { '#check', '#eval', '#reduce' },
  { 'sorry', 'exact?', 'apply?' },
  { 'exact ⟨', 'refine ⟨' },
  { 'aesop', 'aesop?' },
  { 'norm_cast', 'push_cast' },
  vim.fn['switch#Words'] { 'by', 'by?' },
  vim.fn['switch#Words'] { 'tt', 'ff' },
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
  { '|', '∣' },
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
    [ [=[\<simp\(?\?\)\(\s\+only\s\+\[[^\]]*]\)\?]=] ] = function(original)
      if original[2] == '' and original[3] == '' then
        return 'simp?'
      else
        return 'simp'
      end
    end,
  },

  { [segment 'bot'] = 'top', [segment 'top'] = 'bot' },
  { [segment 'inl'] = 'inr', [segment 'inr'] = 'inl' },
  { [segment 'left'] = 'right', [segment 'right'] = 'left' },
  { [segment 'mul'] = 'add', [segment 'add'] = 'mul' },
  { [segment 'zero'] = 'one', [segment 'one'] = 'zero' },
}
