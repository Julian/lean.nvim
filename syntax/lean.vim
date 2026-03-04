" Vim syntax file
" Language:		Lean
" Filename extensions:	*.lean
" Maintainer:           Gabriel Ebner

syn case match

" keywords

syn keyword leanCommand prelude import include export open mutual
syn keyword leanCommandPrefix local private protected scoped partial noncomputable unsafe
syn keyword leanModifier renaming hiding where extends using with at rec deriving
syn keyword leanCommand syntax elab elab_rules macro_rules macro

syn keyword leanCommand namespace section end

syn match leanFrenchQuote '«[^»]*»' contained

syn match leanDeclarationName ' *[^:({\[[:space:]]*' contained
syn match leanDeclarationName ' *«[^»]*»' contained
syn keyword leanDeclaration theorem lemma def axiom abbrev opaque
        \ inductive structure class instance skipwhite nextgroup=leanDeclarationName

syn keyword leanCommand universe example
syn keyword leanCommand variable
syn keyword leanCommand precedence postfix prefix notation infix infixl infixr

syn keyword leanCommand alias
syn keyword leanCommand inline
syn keyword leanCommand unif_hint

syn keyword leanKeyword by by?
syn keyword leanKeyword forall fun from have show assume suffices let if else then in with calc match do this
syn keyword leanKeyword try catch finally for unless return mut continue break
syn keyword leanSort Sort Prop Type
syn keyword leanCommand set_option run_cmd

" Lean.Parser.Command
syn match leanCommand "#check"
syn match leanCommand "#check_failure"
syn match leanCommand "#reduce"
syn match leanCommand "#eval"
syn match leanCommand "#synth"
syn match leanCommand "#exit"
syn match leanCommand "#print"
syn match leanCommand "#print axioms"

" Mathlib commands
syn match leanCommand "#help"
syn match leanCommand "#run"

syn keyword leanSorry sorry admit stop
syn match leanSorry "#exit"

syn region leanAttributeArgs start='\[' end='\]' contained contains=leanString,leanNumber,leanAttributeArgs
syn match leanCommandPrefix '@' nextgroup=leanAttributeArgs
syn keyword leanCommandPrefix attribute skipwhite nextgroup=leanAttributeArgs

" constants
syn match leanOp "[:=><λ←→↔∀∃∧∨¬≤≥▸·+*-/;$|&%!×]"
syn match leanOp '\([A-Za-z]\)\@<!?'

" delimiters
syn region leanEncl matchgroup=leanDelim start="#\[" end="\]" contains=TOP
syn region leanEncl matchgroup=leanDelim start="(" end=")" contains=TOP
syn region leanEncl matchgroup=leanDelim start="\[" end="\]" contains=TOP
syn region leanEncl matchgroup=leanDelim start="⦃"  end="⦄" contains=TOP
syn region leanEncl matchgroup=leanDelim start="⟨"  end="⟩" contains=TOP

syn region leanAnonymousLiteral matchgroup=leanDelim start="⟨"  end="⟩" contains=TOP

" FIXME(gabriel): distinguish backquotes in notations from names
" syn region      leanNotation        start=+`+    end=+`+

syn keyword	leanTodo 	containedin=leanComment TODO FIXME BUG FIX XXX

syn match leanStringEscape '\\.' contained
syn region leanInterpolatedString start='s!"' end='"' contains=leanInterpolation,leanStringEscape
syn region leanString start='"' end='"' contains=leanStringEscape
" HACK: Lean supports both interpolated and non-interpolated strings
" We want "{" to be highlighted as a string (because it often occurs in
" syntax definitions).
syn region leanInterpolation contained start='{\(\s*"\)\@!' skip='{[^}]*}' end='}' contains=TOP keepend

syn match leanChar "'[^\\]'"
syn match leanChar "'\\.'"

syn match leanNumber '\<\d\d*\>'
syn match leanNumber '\<0x[0-9a-fA-F]*\>'
syn match leanNumber '\<\d\d*\.\d*\>'

syn match leanNameLiteral '``*[^ \[()\]}][^ ()\[\]{}]*'
syn match leanNameLiteral '``' nextgroup=leanFrenchQuote

" syn include     @markdown       syntax/markdown.vim
syn region      leanBlockComment start="/-" end="-/" contains=@Spell,leanBlockComment
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
hi def link leanCommandPrefix     PreProc
hi def link leanAttributeArgs     leanCommandPrefix
hi def link leanModifier          Label

hi def link leanDeclaration       leanCommand
hi def link leanDeclarationName   Function

hi def link leanDelim             Delimiter
hi def link leanOp                Operator

hi def link leanNotation          String
hi def link leanString            String
hi def link leanInterpolatedString String
hi def link leanStringEscape      SpecialChar
hi def link leanChar              Character
hi def link leanNumber            Number
hi def link leanNameLiteral       Identifier

hi def link leanSorry             Error

hi def link leanPinned            DiagnosticUnderlineHint
hi def link leanDiffPinned        DiagnosticUnderlineInfo

syn sync minlines=200
syn sync maxlines=500

let b:current_syntax = "lean"

" vim: ts=8 sw=8
