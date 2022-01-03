syn match leanInfoGoals "^▶.*goal.*"
syn match leanInfoGoalCase "^case .*"
syn match leanInfoGoalHyp "^[^:\n< ][^:\n⊢{[(⦃]*\( :\@=\)"
syn match leanInfoGoalVDash "^⊢"

syn match leanInfoExpectedType "^▶ expected type.*"

syn match leanInfoError "^▶.*: error:$"
syn match leanInfoWarning "^▶.*: warning:$"
syn match leanInfoInfo "^▶.*: information:$"
syn match leanInfoComment "--.*"

hi def link leanInfoGoals Title
hi def link leanInfoGoalCase Statement
hi def link leanInfoGoalHyp Type
hi def link leanInfoGoalVDash Operator
hi def link leanInfoExpectedType Special

if luaeval('vim.diagnostic ~= nil')
  " neovim 0.6
  hi def link leanInfoError DiagnosticError
  hi def link leanInfoWarning DiagnosticWarning
  hi def link leanInfoInfo DiagnosticInfo
else
  " neovim 0.5
  hi def link leanInfoError LspDiagnosticsDefaultError
  hi def link leanInfoWarning LspDiagnosticsDefaultWarning
  hi def link leanInfoInfo LspDiagnosticsDefaultInformation
endif
hi def link leanInfoComment Comment
hi def link leanInfoBlockComment Comment

hi def link widgetElementHighlight DiffChange
hi def link widgetElementLoading Comment

hi def link leanInfoExternalHighlight widgetElementHighlight
hi def link leanInfoButton Pmenu
hi def link leanInfoField Folded
hi def link leanInfoFieldAlt Folded
hi def link leanInfoFieldSep DbgBreakPt
