syn match leanInfoGoals "^▶.*goal.*"
syn match leanInfoGoalCase "^case .*"
syn match leanInfoGoalHyp "^[^:\n< ][^:\n⊢{[(⦃]*\( :\@=\)"
syn match leanInfoGoalVDash "^⊢"

syn match leanInfoExpectedType "^▶ expected type.*"

syn match leanInfoError "^▶.*: error:$"
syn match leanInfoWarning "^▶.*: warning:$"
syn match leanInfoInfo "^▶.*: information:$"

hi def link leanInfoGoals Title
hi def leanInfoGoalCase ctermfg=cyan guifg=Cyan
hi def link leanInfoGoalHyp Type
hi def link leanInfoGoalVDash Operator
hi def link leanInfoExpectedType Special

hi def link leanInfoError LspDiagnosticsDefaultError
hi def link leanInfoWarning LspDiagnosticsDefaultWarning
hi def link leanInfoInfo LspDiagnosticsDefaultInformation
