local highlight = vim.cmd.highlight
local syntax = vim.cmd.syntax

local config = require 'lean.config'().infoview

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

---@type table<lsp.Diagnostic, string>
local HLGROUPS = {
  'DiagnosticError',
  'DiagnosticWarn',
  'DiagnosticInfo',
  'DiagnosticOk',
}

---@type string, string
local match, hlgroup
for i, to_group in vim.iter(ipairs(HLGROUPS)) do
  match = config.severity_markers[i]:gsub('\n', [[\_$]])
  hlgroup = 'leanInfo' .. to_group
  syntax(('match %s "^▶.*: %s.*$"'):format(hlgroup, match))
  highlight(('default link %s %s'):format(hlgroup, to_group))
end

syntax [[match leanInfoComment "--.*"]]
highlight [[default link leanInfoComment Comment]]

-- Widgets

syntax [[match widgetSuggestions "^▶ suggestions.*"]]
highlight [[default link widgetSuggestions Title]]

syntax [[match widgetSuggestionsSubgoals "^\s*.emaining subgoals:$"]]
highlight [[default link widgetSuggestionsSubgoals Statement]]

highlight [[default link widgetLink Tag]]

highlight [[default link widgetElementHighlight DiffChange]]
