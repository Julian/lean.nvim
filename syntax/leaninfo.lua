if vim.b.current_syntax == 'leaninfo' then
  return
end

local config = require 'lean.config'().infoview

-- Goal state

vim.api.nvim_set_hl(0, 'leanInfoGoals', { default = true, link = 'Title' })
vim.api.nvim_set_hl(0, 'leanInfoMultipleGoals', { default = true, link = 'DiagnosticHint' })
vim.api.nvim_set_hl(0, 'leanInfoGoalCase', { default = true, link = 'Statement' })
vim.api.nvim_set_hl(0, 'leanInfoGoalPrefix', { default = true, link = 'Operator' })
vim.api.nvim_set_hl(0, 'leanInfoHypName', { default = true, link = 'Type' })
vim.api.nvim_set_hl(0, 'leanInfoInaccessibleHypName', { default = true, link = 'Comment' })
vim.api.nvim_set_hl(0, 'leanInfoSelected', { reverse = true, bold = true })
vim.api.nvim_set_hl(0, 'leanInfoExpectedType', { default = true, link = 'Special' })

-- Infoview state indicators

vim.api.nvim_set_hl(0, 'leanInfoNCWarn', { default = true, link = 'Folded' })
vim.api.nvim_set_hl(0, 'leanInfoNCError', { default = true, link = 'NormalFloat' })
vim.api.nvim_set_hl(0, 'leanInfoPaused', { default = true, link = 'leanInfoNCWarn' })
vim.api.nvim_set_hl(0, 'leanInfoLSPDead', { default = true, link = 'leanInfoNCError' })

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
  vim.cmd.syntax(('match %s "^▼.*: %s.*$"'):format(hlgroup, match))
  vim.api.nvim_set_hl(0, hlgroup, { default = true, link = to_group })
end

vim.cmd.syntax [[match leanInfoComment "--.*"]]
vim.api.nvim_set_hl(0, 'leanInfoComment', { default = true, link = 'Comment' })

-- Goal Diffing

vim.api.nvim_set_hl(0, 'leanInfoHypNameInserted', { default = true, link = 'DiffAdd' })
vim.api.nvim_set_hl(0, 'leanInfoHypNameRemoved', { default = true, link = 'DiffDelete' })

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
  vim.api.nvim_set_hl(0, 'leanInfoDiff' .. diff_tag, { default = true, link = to_group })
end

-- Widgets

vim.api.nvim_set_hl(0, 'widgetSuggestion', { default = true, link = 'Title' })

vim.cmd.syntax [[match widgetSuggestionSubgoals "^\s*.emaining subgoals:$"]]
vim.api.nvim_set_hl(0, 'widgetSuggestionSubgoals', { default = true, link = 'Statement' })

vim.api.nvim_set_hl(0, 'widgetChangedText', { default = true, link = 'Visual' })
vim.api.nvim_set_hl(0, 'widgetLink', { default = true, link = 'Tag' })
vim.api.nvim_set_hl(0, 'widgetKbd', { default = true, link = 'String' })
vim.api.nvim_set_hl(0, 'widgetSelect', { default = true, link = 'Special' })
vim.api.nvim_set_hl(0, 'widgetElementHighlight', { default = true, link = 'DiffChange' })

vim.b.current_syntax = 'leaninfo'
