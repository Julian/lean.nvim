local components = require('lean.infoview.components')
local lean3 = require('lean.lean3')
local leanlsp = require('lean.lsp')
local is_lean_buffer = require('lean').is_lean_buffer
local set_augroup = require('lean._nvimapi').set_augroup

local infoview = { _by_id = {} }
local options = { _DEFAULTS = { autoopen = true, width = 50 } }

local _DEFAULT_BUF_OPTIONS = {
  bufhidden = 'wipe',
  filetype = 'leaninfo',
  modifiable = false,
}
local _DEFAULT_WIN_OPTIONS = {
  cursorline = false,
  number = false,
  relativenumber = false,
  spell = false,
  winfixwidth = true,
  wrap = true,
}
local _NOTHING_TO_SHOW = { "No info found." }

--- An individual infoview.
local Infoview = { is_open = true }

--- An infoview that has been closed.
local ClosedInfoview = { is_open = false }

--- Get the ID of the infoview corresponding to the current window.
local function get_id()
  return vim.api.nvim_win_get_tabpage(0)
end

--- Get the infoview corresponding to the current window.
function infoview.get_current_infoview()
  return infoview._by_id[get_id()] or ClosedInfoview:new()
end

--- Create a new infoview.
---@param id number: the new ID associated with the infoview
---@param width number: the width of the new infoview
function Infoview:new(id, width)
  width = width or options.width

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, "lean://infoview/" .. id)
  for name, value in pairs(_DEFAULT_BUF_OPTIONS) do
    vim.api.nvim_buf_set_option(bufnr, name, value)
  end

  local window_before_split = vim.api.nvim_get_current_win()

  vim.cmd("botright " .. width .. "vsplit")
  vim.cmd(string.format("buffer %d", bufnr))
  local window = vim.api.nvim_get_current_win()
  for name, value in pairs(_DEFAULT_WIN_OPTIONS) do
    vim.api.nvim_win_set_option(window, name, value)
  end
  -- Make sure we notice even if someone manually :q's the infoview window.
  set_augroup("LeanInfoviewClose", string.format([[
    autocmd WinClosed <buffer> lua require'lean.infoview'.__was_closed(%d)
  ]], id))

  local obj = { bufnr = bufnr, window = window }
  setmetatable(obj, self)
  self.__index = self

  vim.api.nvim_set_current_win(window_before_split)

  obj.focus_on_current_buffer()

  return obj
end

--- Do nothing, we're already open.
function Infoview:open()
  return self
end

--- Close this infoview.
function Infoview:close()
  vim.api.nvim_win_close(self.window, true)
  set_augroup("LeanInfoviewUpdate", "", true)
end

--- Toggle this infoview being open.
function Infoview:toggle()
  self:close()
end

--- Set the currently active Lean buffer to update the infoview.
function Infoview.focus_on_current_buffer()
  if not is_lean_buffer() then return end
  set_augroup("LeanInfoviewUpdate", [[
    autocmd CursorHold <buffer> lua require'lean.infoview'.__update()
    autocmd CursorHoldI <buffer> lua require'lean.infoview'.__update()
  ]], true)
end

--- Update this infoview's contents given the new set of lines.
function Infoview:update(lines)
  if vim.tbl_isempty(lines) then lines = _NOTHING_TO_SHOW end

  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, lines)
  -- HACK: This shouldn't really do anything, but I think there's a neovim
  --       display bug. See #27 and neovim/neovim#14663. Specifically,
  --       as of NVIM v0.5.0-dev+e0a01bdf7, without this, updating a long
  --       infoview with shorter contents doesn't properly redraw.
  vim.api.nvim_buf_call(self.bufnr, vim.fn.winline)
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', false)
end

--- Update the infoview contents appropriately for Lean 4 or 3.
--- Normally will be called on each CursorHold for a buffer containing Lean.
function infoview.__update()
  local update = vim.b.lean3 and lean3.update_infoview or function(set_lines)
    return leanlsp.plain_goal(0, function(_, _, goal)
      leanlsp.plain_term_goal(0, function(_, _, term_goal)
        local lines = components.goal(goal)
        if not vim.tbl_isempty(lines) then table.insert(lines, '') end
        vim.list_extend(lines, components.term_goal(term_goal))
        vim.list_extend(lines, components.diagnostics())
        set_lines(lines)
      end)
    end)
  end

  update(function(lines) infoview.get_current_infoview():update(lines) end)
end

--- Retrieve the contents of the infoview as a table.
function Infoview:get_lines(start_line, end_line)
  start_line = start_line or 0
  end_line = end_line or -1
  return vim.api.nvim_buf_get_lines(self.bufnr, start_line, end_line, true)
end

--- Retrieve the current combined contents of the infoview as a string.
function Infoview:get_contents()
  return table.concat(self:get_lines(), "\n")
end

--- Is the infoview not showing anything?
function Infoview:is_empty()
  return vim.deep_equal(self:get_lines(), _NOTHING_TO_SHOW)
end

--- Close all open infoviews (across all tabs).
function infoview.close_all()
  for _, each in pairs(infoview._by_id) do
    each:close()
  end
end

function ClosedInfoview:new()
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  return obj
end

--- Open an infoview.
function ClosedInfoview.open(_)
  local id = get_id()
  local obj = Infoview:new(id)
  infoview._by_id[id] = obj
  return obj
end

--- (Re-)open the infoview.
function ClosedInfoview:toggle()
  return self:open()
end

--- Unhook the updating callback, since this window is closed.
--- Likely this should really be done by having all buffers share the same
--- augroup for one infoview window (and then clearing them all at once on
--- `close()`).
function ClosedInfoview.focus_on_current_buffer()
  set_augroup("LeanInfoviewUpdate", "", true)
end

--- An infoview was closed, either directly via `Infoview.close` or manually.
--- Will be triggered via a `WinClosed` autocmd.
function infoview.__was_closed(id)
  infoview._by_id[id] = ClosedInfoview:new()
end

--- Enable and open the infoview across all Lean buffers.
function infoview.enable(opts)
  options = vim.tbl_extend("force", options._DEFAULTS, opts)
  set_augroup("LeanInfoviewInit", [[
    autocmd FileType lean3 lua require'lean.infoview'.make_buffer_focusable()
    autocmd FileType lean lua require'lean.infoview'.make_buffer_focusable()
  ]])
  infoview.set_autoopen(options.autoopen)
end

--- Configure the infoview to update when this buffer is active.
function infoview.make_buffer_focusable()
  set_augroup("LeanInfoviewSetFocus", [[
    autocmd BufEnter,WinEnter <buffer> lua require'lean.infoview'.get_current_infoview():focus_on_current_buffer()
  ]], true)
end

--- Set whether a new infoview is automatically opened when entering Lean buffers.
function infoview.set_autoopen(autoopen)
  set_augroup("LeanInfoviewAutoopen",
    autoopen and "autocmd BufEnter * lua require'lean.infoview'.maybe_autoopen()" or ""
  )
end

--- Open an infoview for the current buffer if it isn't already open.
function infoview.maybe_autoopen()
  if not is_lean_buffer() then return end
  local id = get_id()
  if not infoview._by_id[id] then infoview._by_id[id] = Infoview:new(id) end
end

return infoview
