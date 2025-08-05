---@mod lean.stderr Standard error buffers

---@brief [[
--- Support for propagating low-level LSP messages emitted on standard error.
---@brief ]]

local log = require 'vim.lsp.log'

local Buffer = require 'std.nvim.buffer'
local Window = require 'std.nvim.window'

local infoview = require 'lean.infoview'

local stderr = {}
local current = {}
local stderr_height

---Open a window for the stderr buffer of the configured height.
---@param stderr_buffer Buffer the buffer to open in the new window
---@return Window stderr_window the newly created window
local function open_window(stderr_buffer)
  local initial_window = Window:current()

  -- split the infoview window if open
  local iv = infoview.get_current_infoview()
  if iv then
    iv:enter()
    vim.cmd(('rightbelow sbuffer %d'):format(stderr_buffer.bufnr))
  else
    vim.cmd(('botright sbuffer %d'):format(stderr_buffer.bufnr))
  end

  local stderr_window = Window:current()
  stderr_window:set_height(stderr_height)
  stderr_buffer.o.filetype = 'leanstderr'
  initial_window:make_current()
  return stderr_window
end

---Show stderr output in a separate stderr buffer.
---@param message string a (possibly multi-line) string from stderr
function stderr.show(message)
  vim.schedule(function()
    if not current.buffer or not current.buffer:is_valid() then
      current.buffer = Buffer.create {
        name = 'lean://stderr',
        listed = false,
        scratch = true,
      }
      current.window = nil
    end
    if not current.window or not current.window:is_valid() then
      current.window = open_window(current.buffer)
    end
    local lines = vim.split(message, '\n')
    local num_lines = current.buffer:line_count()
    if lines[#lines] == '' then
      table.remove(lines)
    end
    num_lines = num_lines + #lines
    vim.api.nvim_buf_set_lines(current.buffer.bufnr, num_lines, num_lines, false, lines)
    if not current.window:is_current() then
      current.window:set_cursor { num_lines, 0 }
    end
  end)
end

---Enable teeing stderr output somewhere (to a second visible buffer by default).
function stderr.enable(config)
  local on_lines = config.on_lines or stderr.show
  local old_error = log.error
  stderr_height = config.height or 5

  -- TODO: add upstream neovim API
  local function patch_log_error()
    if log.error == old_error then
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
  end

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'lean',
    callback = patch_log_error,
    once = true,
  })
end

return stderr
