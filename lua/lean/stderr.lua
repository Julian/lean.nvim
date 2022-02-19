local log = require('vim.lsp.log')

local infoview = require('lean.infoview')
local util = require('lean._util')

local stderr = {}

-- Opens a window for the stderr buffer.
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

-- Show stderr output in separate buffer
-- TODO: add upstream neovim API
function stderr.enable()
  local old_error = log.error
  local stderr_bufnr, stderr_winnr
  log.error = function(...)
    local argc = select('#', ...)
    if argc == 0 then return true end -- always enable error messages
    if argc == 4 and select(1, ...) == 'rpc' and select(3, ...) == 'stderr'
        and string.match(select(2, ...), 'lean') then
      local chunk = select(4, ...)
      vim.schedule(function()
        if not stderr_bufnr or not vim.api.nvim_buf_is_valid(stderr_bufnr) then
          stderr_bufnr = util.create_buf{ name = 'lean://stderr', listed = false, scratch = true }
          stderr_winnr = nil
        end
        if not stderr_winnr or not vim.api.nvim_win_is_valid(stderr_winnr) then
          stderr_winnr = open_window(stderr_bufnr)
        end
        local lines = vim.split(chunk, '\n')
        local num_lines = vim.api.nvim_buf_line_count(stderr_bufnr)
        if lines[#lines] == '' then table.remove(lines) end
        vim.api.nvim_buf_set_lines(stderr_bufnr, num_lines, num_lines, false, lines)
        if vim.api.nvim_get_current_win() ~= stderr_winnr then
          vim.api.nvim_win_set_cursor(stderr_winnr, {num_lines, 0})
        end
      end)
    end
    old_error(...)
  end
end

return stderr
