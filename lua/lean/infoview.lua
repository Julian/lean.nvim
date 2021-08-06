local components = require('lean.infoview.components')
local lean3 = require('lean.lean3')
local leanlsp = require('lean.lsp')
local is_lean_buffer = require('lean').is_lean_buffer
local set_augroup = require('lean._util').set_augroup
local a = require('plenary.async')

local infoview = {
  -- mapping from infoview IDs to infoviews
  _by_id = {},
  -- mapping from tabpage handles to infoviews
  _by_tabpage = {},
  -- mapping from info IDs to infos
  _info_by_id = {},
  -- mapping from pin IDs to pins
  _pin_by_id = {},
}
local options = { _DEFAULTS = { autoopen = true, width = 50 } }

local _DEFAULT_BUF_OPTIONS = {
  bufhidden = 'hide',
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

--- An individual pin.
local Pin = {}

--- An individual info.
local Info = {}

--- A "view" on an info (i.e. window).
local Infoview = {}

--- Get the infoview corresponding to the current window.
function infoview.get_current_infoview()
  return infoview._by_tabpage[vim.api.nvim_win_get_tabpage(0)]
end

--- Create a new infoview.
---@param width number: the width of the new infoview
---@param open boolean: whether to open the infoview after initializing
function Infoview:new(width, open)
  local new_infoview = {id = #infoview._by_id + 1, width = width, info = Info:new()}
  table.insert(infoview._by_id, new_infoview)
  self.__index = self
  setmetatable(new_infoview, self)

  if not open then new_infoview:close() else new_infoview:open() end

  return new_infoview
end

--- Open this infoview if it isn't already open
function Infoview:open()
  if self.is_open then return vim.deepcopy(self) end

  local window_before_split = vim.api.nvim_get_current_win()

  vim.cmd("botright " .. self.width .. "vsplit")
  vim.cmd(string.format("buffer %d", self.info.bufnr))
  local window = vim.api.nvim_get_current_win()
  for name, value in pairs(_DEFAULT_WIN_OPTIONS) do
    vim.api.nvim_win_set_option(window, name, value)
  end
  -- Make sure we notice even if someone manually :q's the infoview window.
  set_augroup("LeanInfoviewClose", string.format([[
    autocmd WinClosed <buffer> lua require'lean.infoview'.__was_closed(%d)
  ]], self.id), 0)

  vim.api.nvim_set_current_win(window_before_split)

  self.window = window
  self.is_open = true

  self:focus_on_current_buffer()

  return vim.deepcopy(self)
end

--- Close this infoview.
function Infoview:close()
  if not self.is_open then
    -- in case it is nil
    self.is_open = false
    return
  end

  set_augroup("LeanInfoviewClose", "", self.bufnr)
  vim.api.nvim_win_close(self.window, true)
  self.window = nil
  self.is_open = false

  self:focus_on_current_buffer()
end

--- Toggle this infoview being open.
function Infoview:toggle()
  if self.is_open then self:close() else self:open() end
end

--- Set the currently active Lean buffer to update the info.
function Infoview:focus_on_current_buffer()
  if not is_lean_buffer() then return end
  if self.is_open then
    set_augroup("LeanInfoviewUpdate", [[
      autocmd CursorHold <buffer> lua require'lean.infoview'.__update()
      autocmd CursorHoldI <buffer> lua require'lean.infoview'.__update()
    ]], 0)
  else
    set_augroup("LeanInfoviewUpdate", "", 0)
  end
end

function Info:new()
  local new_info = {
    id = #infoview._info_by_id + 1,
    bufnr = vim.api.nvim_create_buf(false, true),
    pin = Pin:new()
  }
  new_info.pin:add_parent_info(new_info)
  table.insert(infoview._info_by_id, new_info)

  self.__index = self
  setmetatable(new_info, self)

  vim.api.nvim_buf_set_name(new_info.bufnr, "lean://info/" .. new_info.id)
  for name, value in pairs(_DEFAULT_BUF_OPTIONS) do
    vim.api.nvim_buf_set_option(new_info.bufnr, name, value)
  end

  return new_info
end

local plain_goal = a.wrap(leanlsp.plain_goal, 2)
local plain_term_goal = a.wrap(leanlsp.plain_term_goal, 2)

--- Update this info's physical contents.
function Info:render()
  local lines = self.pin.msg

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

function Pin:new()
  local new_pin = {id = #infoview._pin_by_id + 1, parent_infos = {}}
  table.insert(infoview._pin_by_id, new_pin)

  self.__index = self
  setmetatable(new_pin, self)

  return new_pin
end

function Pin:add_parent_info(info)
  self.parent_infos[info.id] = true
end

--- Update this pin's contents given the current position.
function Pin:update()
  a.void(function()
    local lines
    if vim.opt.filetype:get() == "lean3" then
      lines = lean3.update_infoview()
    else
      local _, _, goal = plain_goal(0)
      local _, _, term_goal = plain_term_goal(0)
      lines = components.goal(goal)
      if not vim.tbl_isempty(lines) then table.insert(lines, '') end
      vim.list_extend(lines, components.term_goal(term_goal))
      vim.list_extend(lines, components.diagnostics())
    end
    self.msg = lines

    for parent_id, _ in pairs(self.parent_infos) do
      infoview._info_by_id[parent_id]:render()
    end
  end)()
end

--- Update the info contents appropriately for Lean 4 or 3.
--- Normally will be called on each CursorHold for a buffer containing Lean.
function infoview.__update()
  infoview.get_current_infoview().info.pin:update()
end

--- Retrieve the contents of the info as a table.
function Info:get_lines(start_line, end_line)
  start_line = start_line or 0
  end_line = end_line or -1
  return vim.api.nvim_buf_get_lines(self.bufnr, start_line, end_line, true)
end

--- Retrieve the current combined contents of the info as a string.
function Info:get_contents()
  return table.concat(self:get_lines(), "\n")
end

--- Is the info not showing anything?
function Info:is_empty()
  return vim.deep_equal(self:get_lines(), _NOTHING_TO_SHOW)
end

--- Close all open infoviews (across all tabs).
function infoview.close_all()
  for _, each in pairs(infoview._by_id) do
    each:close()
  end
end

--- An infoview was closed, either directly via `Infoview.close` or manually.
--- Will be triggered via a `WinClosed` autocmd.
function infoview.__was_closed(id)
  infoview._by_id[id]:close()
end

--- Enable and open the infoview across all Lean buffers.
function infoview.enable(opts)
  options = vim.tbl_extend("force", options._DEFAULTS, opts)
  set_augroup("LeanInfoviewInit", [[
    autocmd FileType lean3 lua require'lean.infoview'.make_buffer_focusable()
    autocmd FileType lean lua require'lean.infoview'.make_buffer_focusable()
  ]])
end

--- Configure the infoview to update when this buffer is active.
function infoview.make_buffer_focusable()
  -- WinEnter is necessary for the edge case where you have
  -- a file open in a tab with an infoview and move to a
  -- new window in a new tab with that same file but no infoview
  set_augroup("LeanInfoviewSetFocus", [[
    autocmd BufEnter <buffer> lua require'lean.infoview'.maybe_autoopen()
    autocmd BufEnter,WinEnter <buffer> lua if require'lean.infoview'.get_current_infoview()]] ..
    [[ then require'lean.infoview'.get_current_infoview():focus_on_current_buffer() end
  ]], 0)
end

--- Set whether a new infoview is automatically opened when entering Lean buffers.
function infoview.set_autoopen(autoopen)
  options.autoopen = autoopen
end

--- Open an infoview for the current buffer if it isn't already open.
function infoview.maybe_autoopen()
  local tabpage = vim.api.nvim_win_get_tabpage(0)
  if not infoview._by_tabpage[tabpage] then
    infoview._by_tabpage[tabpage] = Infoview:new(options.width, options.autoopen)
  end
end

return infoview
