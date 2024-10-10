local highlight = vim.cmd.highlight
local syntax = vim.cmd.syntax

-- Goal state

syntax [[match leanInfoGoals "^▶.*goal.*"]]
highlight [[default link leanInfoGoals Title]]

syntax [[match leanInfoGoalCase "^case .*"]]
highlight [[default link leanInfoGoalCase Statement]]

syntax [[match leanInfoGoalHyp "^[^:\n< ][^:\n⊢{[(⦃]*\( :\@=\)" contains=leanInfoInaccessibleHyp]]
highlight [[default link leanInfoGoalHyp Type]]

syntax [[match leanInfoGoalVDash "^⊢"]]
highlight [[default link leanInfoGoalVDash Operator]]

syntax [[match leanInfoGoalConv "^|"]]
highlight [[default link leanInfoGoalConv Operator]]

syntax [[match leanInfoInaccessibleHyp "\i\+✝" contained]]
highlight [[default link leanInfoInaccessibleHyp Comment]]

syntax [[match leanInfoExpectedType "^▶ expected type.*"]]
highlight [[default link leanInfoExpectedType Special]]

-- Diagnostics

syntax [[match leanInfoError "^▶.*: error:$"]]
highlight [[default link leanInfoError DiagnosticError]]

syntax [[match leanInfoWarning "^▶.*: warning:$"]]
highlight [[default link leanInfoWarning DiagnosticWarn]]

syntax [[match leanInfoInfo "^▶.*: information:$"]]
highlight [[default link leanInfoInfo DiagnosticInfo]]

syntax [[match leanInfoComment "--.*"]]
highlight [[default link leanInfoComment Comment]]

-- Widgets

syntax [[match widgetSuggestions "^▶ suggestions.*"]]
highlight [[default link widgetSuggestions Title]]

syntax [[match widgetSuggestionsSubgoals "^\s*.emaining subgoals:$"]]
highlight [[default link widgetSuggestionsSubgoals Statement]]

highlight [[default link widgetLink Tag]]

highlight [[default link widgetElementHighlight DiffChange]]
