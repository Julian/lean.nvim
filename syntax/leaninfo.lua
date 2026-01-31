local syntax = vim.cmd.syntax

local config = require 'lean.config'().infoview

-- Goal state

vim.api.nvim_set_hl(0, 'leanInfoGoals', { link = 'Title' })
vim.api.nvim_set_hl(0, 'leanInfoMultipleGoals', { link = 'DiagnosticHint' })
vim.api.nvim_set_hl(0, 'leanInfoGoalCase', { link = 'Statement' })
vim.api.nvim_set_hl(0, 'leanInfoGoalPrefix', { link = 'Operator' })
vim.api.nvim_set_hl(0, 'leanInfoHypName', { link = 'Type' })
vim.api.nvim_set_hl(0, 'leanInfoInaccessibleHypName', { link = 'Comment' })
vim.api.nvim_set_hl(0, 'leanInfoSelected', { reverse = true, bold = true })
vim.api.nvim_set_hl(0, 'leanInfoExpectedType', { link = 'Special' })

-- Infoview state indicators

vim.api.nvim_set_hl(0, 'leanInfoNCWarn', { link = 'Folded' })
vim.api.nvim_set_hl(0, 'leanInfoNCError', { link = 'NormalFloat' })
vim.api.nvim_set_hl(0, 'leanInfoPaused', { link = 'leanInfoNCWarn' })
vim.api.nvim_set_hl(0, 'leanInfoLSPDead', { link = 'leanInfoNCError' })

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
  syntax(('match %s "^▼.*: %s.*$"'):format(hlgroup, match))
  vim.api.nvim_set_hl(0, hlgroup, { link = to_group })
end

syntax [[match leanInfoComment "--.*"]]
vim.api.nvim_set_hl(0, 'leanInfoComment', { link = 'Comment' })

-- Goal Diffing

vim.api.nvim_set_hl(0, 'leanInfoHypNameInserted', { link = 'DiffAdd' })
vim.api.nvim_set_hl(0, 'leanInfoHypNameRemoved', { link = 'DiffDelete' })

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
  vim.api.nvim_set_hl(0, 'leanInfoDiff' .. diff_tag, { link = to_group })
end

-- Widgets

vim.api.nvim_set_hl(0, 'widgetSuggestion', { link = 'Title' })

syntax [[match widgetSuggestionSubgoals "^\s*.emaining subgoals:$"]]
vim.api.nvim_set_hl(0, 'widgetSuggestionSubgoals', { link = 'Statement' })

vim.api.nvim_set_hl(0, 'widgetChangedText', { link = 'Visual' })
vim.api.nvim_set_hl(0, 'widgetLink', { link = 'Tag' })
vim.api.nvim_set_hl(0, 'widgetKbd', { link = 'String' })
vim.api.nvim_set_hl(0, 'widgetSelect', { link = 'Special' })
vim.api.nvim_set_hl(0, 'widgetElementHighlight', { link = 'DiffChange' })
