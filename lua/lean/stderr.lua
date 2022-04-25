local log = require('vim.lsp.log')

local infoview = require('lean.infoview')
local util = require('lean._util')

local stderr = {}
local current = {}

--- Open a window for the stderr buffer.
local function open_window(stderr_bufnr)
  local old_win = vim.api.nvim_get_current_win()

  -- split the infoview window if open
  local iv = infoview.get_current_infoview()
  if iv and iv.window and vim.api.nvim_win_is_valid(iv.window) then
    vim.api.nvim_set_current_win(iv.window)
    vim.cmd(('rightbelow sbuffer %d'):format(stderr_bufnr))
  else
    vim.cmd(('botright sbuffer %d'):format(stderr_bufnr))
  end

  vim.cmd'resize 5'
  local stderr_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_buf_set_option(stderr_bufnr, 'filetype', 'leanstderr')
  vim.api.nvim_set_current_win(old_win)
  return stderr_winnr
end

---Show stderr output in a separate stderr buffer.
---@param string message @a (possibly multi-line) string from stderr
function stderr.show(message)
  vim.schedule(function()
    if not current.bufnr or not vim.api.nvim_buf_is_valid(current.bufnr) then
      current.bufnr = util.create_buf{ name = 'lean://stderr', listed = false, scratch = true }
      current.winnr = nil
    end
    if not current.winnr or not vim.api.nvim_win_is_valid(current.winnr) then
      current.winnr = open_window(current.bufnr)
    end
    local lines = vim.split(message, '\n')
    local num_lines = vim.api.nvim_buf_line_count(current.bufnr)
    if lines[#lines] == '' then table.remove(lines) end
    vim.api.nvim_buf_set_lines(current.bufnr, num_lines, num_lines, false, lines)
    if vim.api.nvim_get_current_win() ~= current.winnr then
      vim.api.nvim_win_set_cursor(current.winnr, {num_lines, 0})
    end
  end)
end

--- Enable teeing stderr output somewhere (to a second visible buffer by default).
function stderr.enable(config)
  local on_lines = config.on_lines or stderr.show
  local old_error = log.error
  -- TODO: add upstream neovim API
  log.error = function(...)
    local argc = select('#', ...)
    if argc == 0 then return true end -- always enable error messages
    if argc == 4 and select(1, ...) == 'rpc' and select(3, ...) == 'stderr'
        and string.match(select(2, ...), 'lean') then
      local chunk = select(4, ...)
      on_lines(chunk)
    end
    old_error(...)
  end
end

return stderr
