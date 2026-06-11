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

---Open a window for the stderr buffer of the configured height.
---@param stderr_buffer Buffer the buffer to open in the new window
---@return Window stderr_window the newly created window
local function open_window(stderr_buffer)
  local initial_window = Window:current()

  local stderr_window
  -- split the infoview window if open
  local iv = infoview.get_current_infoview()
  if iv and iv.window and iv.window:is_valid() then
    stderr_window = iv.window:split {
      buffer = stderr_buffer,
      direction = 'below',
      enter = true,
    }
  else
    vim.cmd(('botright sbuffer %d'):format(stderr_buffer.bufnr))
    stderr_window = Window:current()
  end
  stderr_window:set_height(require 'lean.config'().stderr.height)
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
        options = { buftype = 'nofile' },
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
    current.buffer:set_lines(lines, num_lines, num_lines, false)
    if not current.window:is_current() then
      current.window:set_cursor { num_lines, 0 }
    end
  end)
end

local initialized = false

---Start teeing stderr output somewhere (to a second visible buffer by default).
---
---Runs automatically via our Lean ftplugin, i.e. lazily when opening Lean
---buffers.
function stderr.init()
  if initialized or require 'lean.config'().stderr.enable == false then
    return
  end
  initialized = true

  -- TODO: add upstream neovim API
  --
  -- Newer nvim (>= 0.13) routes LSP server stderr via the underlying
  -- `vim.lsp.log._self.error(...)` with first arg `'transport'`; older nvim
  -- calls `vim.lsp.log.error(...)` with first arg `'rpc'`. Patch the table
  -- the transport actually reads from in either case.
  local target = log._self or log
  local old_error = target.error

  target.error = function(...)
    local argc = select('#', ...)
    if argc == 0 then
      return true
    end -- always enable error messages
    local mode = select(1, ...)
    local cmd = select(2, ...)
    if
      argc == 4
      and (mode == 'rpc' or mode == 'transport')
      and (cmd == 'lake' or cmd == 'lean')
      and select(3, ...) == 'stderr'
    then
      local chunk = select(4, ...)
      local on_lines = require 'lean.config'().stderr.on_lines or stderr.show
      on_lines(chunk)
    end
    old_error(...)
  end
end

return stderr
