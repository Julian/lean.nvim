---@mod lean.stderr Standard error buffers

---@brief [[
--- Support for propagating low-level LSP messages emitted on standard error.
---@brief ]]

local log = require 'vim.lsp.log'

local Window = require 'std.nvim.window'

local infoview = require 'lean.infoview'
local util = require 'lean._util'

local stderr = {}
local current = {}
local stderr_height

---Open a window for the stderr buffer of the configured height.
local function open_window(stderr_bufnr)
  local old_win = Window:current()

  -- split the infoview window if open
  local iv = infoview.get_current_infoview()
  if iv then
    iv:enter()
    vim.cmd(('rightbelow sbuffer %d'):format(stderr_bufnr))
  else
    vim.cmd(('botright sbuffer %d'):format(stderr_bufnr))
  end

  vim.cmd(('resize %d'):format(stderr_height))
  local stderr_winnr = vim.api.nvim_get_current_win()
  vim.bo[stderr_bufnr].filetype = 'leanstderr'
  old_win:make_current()
  return stderr_winnr
end

---Show stderr output in a separate stderr buffer.
---@param message string a (possibly multi-line) string from stderr
function stderr.show(message)
  vim.schedule(function()
    if not current.bufnr or not vim.api.nvim_buf_is_valid(current.bufnr) then
      current.bufnr = util.create_buf { name = 'lean://stderr', listed = false, scratch = true }
      current.winnr = nil
    end
    if not current.winnr or not vim.api.nvim_win_is_valid(current.winnr) then
      current.winnr = open_window(current.bufnr)
    end
    local lines = vim.split(message, '\n')
    local num_lines = vim.api.nvim_buf_line_count(current.bufnr)
    if lines[#lines] == '' then
      table.remove(lines)
    end
    num_lines = num_lines + #lines
    vim.api.nvim_buf_set_lines(current.bufnr, num_lines, num_lines, false, lines)
    if vim.api.nvim_get_current_win() ~= current.winnr then
      vim.api.nvim_win_set_cursor(current.winnr, { num_lines, 0 })
    end
  end)
end

---Enable teeing stderr output somewhere (to a second visible buffer by default).
function stderr.enable(config)
  local on_lines = config.on_lines or stderr.show
  local old_error = log.error
  stderr_height = config.height or 5
  -- TODO: add upstream neovim API
  log.error = function(...)
    local argc = select('#', ...)
    if argc == 0 then
      return true
    end -- always enable error messages
    if
      argc == 4
      and select(1, ...) == 'rpc'
      and select(3, ...) == 'stderr'
      and string.match(select(2, ...), 'lean')
    then
      local chunk = select(4, ...)
      on_lines(chunk)
    end
    old_error(...)
  end
end

return stderr
