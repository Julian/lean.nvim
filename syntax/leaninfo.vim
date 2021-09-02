syn match leanInfoGoals "^▶.*goal.*"
syn match leanInfoGoalCase "^case .*"
syn match leanInfoGoalHyp "^[^:\n< ][^:\n⊢{[(⦃]*\( :\@=\)"
syn match leanInfoGoalVDash "^⊢"

syn match leanInfoExpectedType "^▶ expected type.*"

syn match leanInfoError "^▶.*: error:$"
syn match leanInfoWarning "^▶.*: warning:$"
syn match leanInfoInfo "^▶.*: information:$"
syn match leanInfoComment "--.*"
syn region leanInfoBlockComment start="/-" end="-/"

hi def link leanInfoGoals Title
hi def link leanInfoGoalCase Statement
hi def link leanInfoGoalHyp Type
hi def link leanInfoGoalVDash Operator
hi def link leanInfoExpectedType Special

hi def link leanInfoError LspDiagnosticsDefaultError
hi def link leanInfoWarning LspDiagnosticsDefaultWarning
hi def link leanInfoInfo LspDiagnosticsDefaultInformation
hi def link leanInfoComment Comment
hi def link leanInfoBlockComment Comment

highlight leanInfoHighlight ctermbg=153 ctermfg=0
highlight leanInfoExternalHighlight ctermbg=12 ctermfg=15
highlight leanInfoTooltip ctermbg=225 ctermfg=0
highlight leanInfoTooltipSep ctermbg=3 ctermfg=0
highlight leanInfoButton ctermbg=249 ctermfg=0
highlight leanInfoField ctermbg=12 ctermfg=0
highlight leanInfoFieldAlt ctermbg=7 ctermfg=0
highlight leanInfoFieldSep ctermbg=225 ctermfg=4
highlight leanInfoGoals cterm=bold
