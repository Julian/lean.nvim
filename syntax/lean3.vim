" Vim syntax file
" Language:		Lean 3
" Filename extensions:	*.lean
" Maintainer:           Gabriel Ebner

syn case match

" Add . to keywords for syntax purposes
syn iskeyword a-z,A-Z,_,48-57,192-255,!,.

" keywords

syn keyword leanCommand prelude import include omit export open open_locale mutual
syn keyword leanCommandPrefix local localized private protected noncomputable meta
syn keyword leanModifier renaming hiding where extends using with at only rec deriving

syn keyword leanCommand namespace section

syn match leanFrenchQuote '«[^»]*»'

syn match leanDeclarationName ' *[^:({\[[:space:]]*' contained
syn match leanDeclarationName ' *«[^»]*»' contained
syn keyword leanDeclaration lemma theorem def definition axiom axioms constant abbrev abbreviation
        \ inductive coinductive structure class instance skipwhite nextgroup=leanDeclarationName

syn keyword leanCommand universe universes example axioms constants
syn keyword leanCommand meta parameter parameters variable variables
syn keyword leanCommand reserve precedence postfix prefix notation infix infixl infixr

syn keyword leanTactic
        \ abel abstract ac_mono ac_refl all_goals any_goals apply
        \ apply_assumption apply_auto_param apply_congr apply_fun
        \ apply_instance apply_opt_param apply_rules apply_with
        \ assoc_rewrite assume assumption async by_cases by_contra
        \ by_contradiction calc cancel_denoms case cases cases_matching
        \ casesm cases_type cc change choose classical clear
        \ clear_aux_decl clear_except clear_value comp_val congr
        \ constructor continuity contradiction contrapose
        \ convert convert_to dec_trivial delta destruct done
        \ dsimp dunfold eapply econstructor elide unelide equiv_rw
        \ equiv_rw_type erewrite erw exact exacts exfalso existsi
        \ ext1 ext extract_goal fail_if_success fapply fconstructor
        \ field_simp filter_upwards fin_cases finish clarify safe
        \ focus from fsplit funext generalize generalize_hyp
        \ generalize_proofs generalizes group guard_hyp guard_target
        \ h_generalize have hint induction inhabit injection injections
        \ injections_and_clear interval_cases intro intros introv
        \ itauto iterate left right let library_search lift linarith
        \ linear_combination mapply match_target measurability mono
        \ nlinarith noncomm_ring nontriviality norm_cast norm_fin
        \ norm_num nth_rewrite nth_rewrite_lhs nth_rewrite_rhs observe
        \ obtain omega pi_instance pretty_cases push_neg rcases refine
        \ refine_struct refl reflexivity rename rename_var repeat
        \ replace revert revert_after revert_deps revert_target_deps
        \ rewrite_search ring ring2 ring_exp rintro rintros rotate rw
        \ rewrite rwa scc show show_term simp simp_intros simp_result
        \ simp_rw simpa skip slice solve1 solve_by_elim
        \ specialize split split_ifs squeeze_simp squeeze_simpa
        \ squeeze_dsimp squeeze_scope subst subst_vars substs
        \ subtype_instance success_if_fail suffices suggest swap
        \ swap_var symmetry tautology tfae tidy trace trace_simp_set
        \ trace_state transitivity transport triv trivial trunc_cases
        \ try type_check unfold unfold1 unfold_cases unfold_coes
        \ unfold_projs unify_equations use with_cases wlog zify
        \ to_lhs to_rhs conv_lhs conv_rhs
        \ resetI unfreezingI introI introsI casesI substI haveI letI exactI
        \ exact_mod_cast apply_mod_cast rw_mod_cast assumption_mod_cast
        \ contained
" Try to highlight `set` the tactic while ignoring set-the-type annotation
syn match  leanTactic '\(→\s*\)\@<!\<set \(\k\+)\)\@!' contained
syn match  leanTactic '\<conv\>' contained skipwhite skipempty nextgroup=leanTacticBlock,leanTactic,leanSorry
syn match  leanSemi ';' skipwhite skipempty nextgroup=leanTacticBlock,leanTactic,leanSorry
syn match  leanBy '\<by\>' skipwhite skipempty nextgroup=leanTacticBlock,leanTactic,leanSorry
syn region leanTacticBlock start='{' end='}' contained
    \ contains=ALLBUT,leanKeyword,leanDeclarationName,leanEncl,leanAttributeArgs
syn region leanTacticMode matchgroup=Label start='\<begin\>' end='\<end\>'
    \ contains=ALLBUT,leanKeyword,leanDeclarationName,leanEncl,leanAttributeArgs

syn keyword leanKeyword end
syn keyword leanKeyword forall fun Pi from have show assume let if else then
                      \ in calc match do this suffices
syn keyword leanSort Sort Prop Type
syn keyword leanCommand set_option run_cmd
syn match leanCommand "#eval"
syn match leanCommand "#check"
syn match leanCommand "#print"
syn match leanCommand "#reduce"
syn match leanCommand "#norm_num"
syn match leanCommand "#explode"
syn match leanCommand "#explode_widget"

syn keyword leanSorry sorry
syn keyword leanSorry admit
syn match leanSorry "#exit"

syn region leanAttributeArgs start='\[' end='\]' contained contains=leanString,leanNumber,leanAttributeArgs
syn match leanCommandPrefix '@' nextgroup=leanAttributeArgs
syn keyword leanCommandPrefix attribute skipwhite nextgroup=leanAttributeArgs

" constants
syn match leanOp "[:=><λ←→↔∀∃∧∨¬≤≥▸·+*-/$|&%!×]"
syn match leanOp '\([A-Za-z]\)\@<!?'

" delimiters
syn region leanEncl matchgroup=leanDelim start="#\[" end="\]" contains=TOP
syn region leanEncl matchgroup=leanDelim start="(" end=")" contains=TOP
syn region leanEncl matchgroup=leanDelim start="\[" end="\]" contains=TOP
syn region leanEncl matchgroup=leanDelim start="{"  end="}" contains=TOP
syn region leanEncl matchgroup=leanDelim start="⦃"  end="⦄" contains=TOP
syn region leanEncl matchgroup=leanDelim start="⟨"  end="⟩" contains=TOP

" FIXME(gabriel): distinguish backquotes in notations from names
" syn region      leanNotation        start=+`+    end=+`+

syn keyword	leanTodo 	containedin=leanComment TODO FIXME BUG FIX

syn match leanStringEscape '\\.' contained
syn region leanString start='"' end='"' contains=leanStringEscape

syn match leanChar "'[^\\]'"
syn match leanChar "'\\.'"

syn match leanNumber '\<\d\d*\>'
syn match leanNumber '\<0x[0-9a-fA-F]*\>'
syn match leanNumber '\<\d\d*\.\d*\>'

syn match leanNameLiteral '``*[^ \[()\]}][^ ()\[\]{}]*'

" syn include     @markdown       syntax/markdown.vim
syn region      leanBlockComment start="/-" end="-/" contains=@markdown,@Spell,leanBlockComment
syn match       leanComment     "--.*" contains=@Spell
" fix up some highlighting links for markdown
hi! link markdownCodeBlock Comment
hi! link markdownError Comment

if exists('b:current_syntax')
    unlet b:current_syntax
endif

hi def link leanReference         Identifier
hi def link leanTodo              Todo

hi def link leanComment           Comment
hi def link leanBlockComment      leanComment

hi def link leanKeyword           Keyword
hi def link leanSort              Type
hi def link leanCommand           leanKeyword
hi def link leanTactic            Keyword
hi def link leanBy                Label
hi def link leanCommandPrefix     PreProc
hi def link leanAttributeArgs     leanCommandPrefix
hi def link leanModifier          Label

hi def link leanDeclaration       leanCommand
hi def link leanDeclarationName   Function

hi def link leanDelim             Delimiter
hi def link leanSemi              Delimiter
hi def link leanOp                Operator

hi def link leanNotation          String
hi def link leanString            String
hi def link leanStringEscape      SpecialChar
hi def link leanChar              Character
hi def link leanNumber            Number
hi def link leanNameLiteral       Identifier

hi def link leanSorry             Error

hi def link leanPinned            DiagnosticUnderlineHint
hi def link leanDiffPinned        DiagnosticUnderlineInfo

syn sync minlines=200
syn sync maxlines=500

let b:current_syntax = "lean3"

" vim: ts=8 sw=8
