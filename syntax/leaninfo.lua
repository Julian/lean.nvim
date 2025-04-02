local highlight = vim.cmd.highlight
local syntax = vim.cmd.syntax

local config = require 'lean.config'().infoview

-- Goal state

highlight [[default link leanInfoGoals Title]]
highlight [[default link leanInfoMultipleGoals DiagnosticHint]]
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
local DIAGNOSTIC_HLGROUPS = {
  'DiagnosticError',
  'DiagnosticWarn',
  'DiagnosticInfo',
  'DiagnosticOk',
}

---@type string, string
local match, hlgroup
for i, to_group in vim.iter(ipairs(DIAGNOSTIC_HLGROUPS)) do
  match = config.severity_markers[i]:gsub('\n', [[\_$]])
  hlgroup = 'leanInfo' .. to_group
  syntax(('match %s "^▶.*: %s.*$"'):format(hlgroup, match))
  highlight(('default link %s %s'):format(hlgroup, to_group))
end

syntax [[match leanInfoComment "--.*"]]
highlight [[default link leanInfoComment Comment]]

-- Goal Diffing

highlight [[default link leanInfoHypNameInserted DiffAdd]]
highlight [[default link leanInfoHypNameRemoved DiffDelete]]

---@type table<DiffTag, string>
local DIFF_TAG_HLGROUPS = {
  wasChanged = 'DiffText',
  willChange = 'DiffDelete',
  wasInserted = 'DiffAdd',
  willInsert = 'DiffAdd',
  wasDeleted = 'DiffDelete',
  willDelete = 'DiffDelete',
}
for diff_tag, to_group in vim.iter(DIFF_TAG_HLGROUPS) do
  highlight(('default link leanInfoDiff%s %s'):format(diff_tag, to_group))
end

-- Widgets

highlight [[default link widgetSuggestion Title]]

syntax [[match widgetSuggestionSubgoals "^\s*.emaining subgoals:$"]]
highlight [[default link widgetSuggestionSubgoals Statement]]

highlight [[default link widgetLink Tag]]
highlight [[default link widgetElementHighlight DiffChange]]
