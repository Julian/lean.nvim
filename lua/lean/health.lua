---@mod lean.health Health checks

---@brief [[
--- Support for `:checkhealth` for lean.nvim.
---@brief ]]

local check_output = require('std.subprocess').check_output

local MIN_SUPPORTED_NVIM = '0.11'

local function neovim_is_new_enough()
  local version = vim.version()
  if vim.version.lt(vim.version(), MIN_SUPPORTED_NVIM) then
    local message = 'Neovim is too old. %s is the earliest supported version.'
    vim.health.error(message:format(MIN_SUPPORTED_NVIM))
  else
    vim.health.ok 'Neovim is new enough.'
  end
  vim.health.info(('  `vim.version()`:  %s'):format(version))
end

local function lake_is_runnable()
  local version = vim.trim(check_output { 'lake', '--version' })
  vim.health.ok 'Lake is runnable.'
  vim.health.info(('  `lake --version`:  %s'):format(version))
end

local function no_timers()
  if not vim.tbl_isempty(vim.fn.timer_info()) then
    vim.health.warn(
      'You have active timers, which can degrade infoview (CursorMoved) performance.',
      { 'See https://github.com/Julian/lean.nvim/issues/92' }
    )
  end
end

return {
  ---Check whether lean.nvim is healthy.
  ---
  ---Call me via `:checkhealth lean`.
  check = function()
    local version = require('lean').plugin_version()
    vim.health.start(('lean.nvim (%s)'):format(version))
    neovim_is_new_enough()
    lake_is_runnable()
    no_timers()
  end,
}
