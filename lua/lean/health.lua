---@brief [[
--- Support for `:checkhealth` for lean.nvim.
---@brief ]]

local subprocess_check_output = require('lean._util').subprocess_check_output

local function check_lean_runnable()
  local lean = subprocess_check_output { command = 'lean', args = { '--version' } }
  vim.health.ok '`lean --version`'
  vim.health.info(table.concat(lean, '\n'))
end

local function check_for_timers()
  if not vim.tbl_isempty(vim.fn.timer_info()) then
    vim.health.warn(
      'You have active timers, which can degrade infoview (CursorMoved) '
        .. 'performance. See https://github.com/Julian/lean.nvim/issues/92.'
    )
  end
end

return {
  --- Check whether lean.nvim is healthy.
  ---
  --- Call me via `:checkhealth lean`.
  check = function()
    vim.health.start 'lean.nvim'
    check_lean_runnable()
    check_for_timers()
  end,
}
