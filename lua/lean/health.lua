---@brief [[
--- Support for `:checkhealth` for lean.nvim.
---@brief ]]

local Job = require('plenary.job')
local subprocess_check_output = require('lean._util').subprocess_check_output

local health = {
  report = { __index = function (_, key) return vim.fn['health#report_' .. key] end }
}
setmetatable(health.report, health.report)

local function check_lean_runnable()
  local lean = subprocess_check_output{ command = "lean", args = { "--version" } }
  health.report.ok('`lean --version`')
  health.report.info(table.concat(lean, '\n'))
end

local function check_lean3ls_runnable()
  local succeeded, lean3ls = pcall(Job.new, Job, {
    command = 'lean-language-server',
    args = { '--stdio' },
    writer = ''
  })
  if succeeded then
    lean3ls:sync()
    health.report.ok('`lean-language-server`')
  else
    health.report.warn('`lean-language-server` not found, lean 3 support will not work')
  end
end

local function check_for_timers()
  if not vim.tbl_isempty(vim.fn.timer_info()) then
    health.report.warn(
      'You have active timers, which can degrade infoview (CursorMoved) ' ..
      'performance. See https://github.com/Julian/lean.nvim/issues/92.'
    )
  end
end

--- Check whether lean.nvim is healthy.
---
--- Call me via `:checkhealth lean`.
function health.check()
    health.report.start('lean.nvim')
    check_lean_runnable()
    check_lean3ls_runnable()
    check_for_timers()
end

return health
