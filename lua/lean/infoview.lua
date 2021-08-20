local components = require('lean.infoview.components')
local lean3 = require('lean.lean3')
local leanlsp = require('lean.lsp')
local is_lean_buffer = require('lean').is_lean_buffer
local util = require('lean._util')
local set_augroup = util.set_augroup
local a = require('plenary.async')
local rpc = require'lean.rpc'
local html = require'lean.html'

local infoview = {
  -- mapping from infoview IDs to infoviews
  ---@type table<number, Infoview>
  _by_id = {},
  -- mapping from tabpage handles to infoviews
  ---@type table<any, Infoview>
  _by_tabpage = {},
  -- mapping from info IDs to infos
  ---@type table<number, Info>
  _info_by_id = {},
  -- mapping from pin IDs to pins
  ---@type table<number, Pin>
  _pin_by_id = {},
}
local options = { _DEFAULTS = { autoopen = true, width = 50 } }

local _NOTHING_TO_SHOW = { "No info found." }

--- An individual pin.
---@class Pin
---@field id number
---@field parent_infos table<number, boolean>
local Pin = {}

--- An individual info.
---@class Info
---@field id number
---@field bufnr number
---@field pin Pin
local Info = {}

--- A "view" on an info (i.e. window).
---@class Infoview
---@field id number
---@field bufnr number
---@field width number
---@field info Info
local Infoview = {}

--- Get the infoview corresponding to the current window.
---@return Infoview
function infoview.get_current_infoview()
  return infoview._by_tabpage[vim.api.nvim_win_get_tabpage(0)]
end

--- Create a new infoview.
---@param width number: the width of the new infoview
---@param open boolean: whether to open the infoview after initializing
---@return Infoview
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
  local window_before_split = vim.api.nvim_get_current_win()

  vim.cmd("botright " .. self.width .. "vsplit")
  vim.cmd(string.format("buffer %d", self.info.bufnr))
  local window = vim.api.nvim_get_current_win()

  -- Make sure we notice even if someone manually :q's the infoview window.
  set_augroup("LeanInfoviewClose", string.format([[
    autocmd WinClosed <buffer> lua require'lean.infoview'.__was_closed(%d)
  ]], self.id), 0)

  vim.api.nvim_set_current_win(window_before_split)

  self.window = window
  self.is_open = true

  self:focus_on_current_buffer()
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
  self.info:close()

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
      autocmd CursorMoved <buffer> lua require'lean.infoview'.__update()
      autocmd CursorMovedI <buffer> lua require'lean.infoview'.__update()
    ]], 0)
  else
    set_augroup("LeanInfoviewUpdate", "", 0)
  end
end

---@return Info
function Info:new()
  local new_info = {
    id = #infoview._info_by_id + 1,
    bufnr = vim.api.nvim_create_buf(false, true),
    pin = Pin:new()
  }
  util.load_mappings(require"lean".info_mappings, new_info.bufnr)
  new_info.pin:add_parent_info(new_info)
  table.insert(infoview._info_by_id, new_info)

  self.__index = self
  setmetatable(new_info, self)

  vim.api.nvim_buf_set_name(new_info.bufnr, "lean://info/" .. new_info.id)
  vim.api.nvim_buf_set_option(new_info.bufnr, 'filetype', 'leaninfo')

  return new_info
end

function Info:widget()
  local pos = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, pos[1] - 1, true)
  local raw_pos = 0
  for _, line in pairs(lines) do
    raw_pos = raw_pos + #line + 1
  end
  raw_pos = raw_pos + pos[2] + 1

  local _, div_stack = self.div:div_from_pos(raw_pos)
  require"vim.lsp.util".open_floating_preview(vim.split(vim.inspect(div_stack[#div_stack]), "\n"), nil, {})
end

function Info:close()
  self.pin:close()
end

--- Update this info's physical contents.
function Info:render()
  self.div = html.Div:new()
  self.div:add_div(self.pin.div)
  local lines = vim.split(self.div:render(), "\n")

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

---@return Pin
function Pin:new()
  local new_pin = {id = #infoview._pin_by_id + 1, parent_infos = {}, tick = 0}
  table.insert(infoview._pin_by_id, new_pin)

  self.__index = self
  setmetatable(new_pin, self)

  return new_pin
end

function Pin:close()
  self.sess = nil
end

---@param info Info
function Pin:add_parent_info(info)
  self.parent_infos[info.id] = true
end

local plain_goal = a.wrap(leanlsp.plain_goal, 2)
local plain_term_goal = a.wrap(leanlsp.plain_term_goal, 2)

local wait_timer = a.wrap(vim.loop.timer_start, 4)

function Pin:reset_rpc()
  self.sess = rpc.open()
end

--- Update this pin's contents given the current position.
function Pin:update()
  a.void(function()
    self.tick = (self.tick + 1) % 1000
    local this_tick = self.tick

    wait_timer(vim.loop.new_timer(), 100, 0)
    a.util.scheduler()
    if self.tick ~= this_tick then return end

    self.div = html.Div:new()

    if vim.opt.filetype:get() == "lean3" then
      lean3.update_infoview(self.div)
    else
      self:reset_rpc()

      local _, _, goal = plain_goal(0)
      if self.tick ~= this_tick then return end

      components.goal(self.div, goal)

      local term_goal, term_goal_err =
        self.sess:getInteractiveTermGoal(vim.lsp.util.make_position_params())
      if term_goal_err then
        _, _, term_goal = plain_term_goal(0)
        components.term_goal(self.div, term_goal)
      else
        components.interactive_term_goal(self.div, term_goal)
      end
      if self.tick ~= this_tick then return end

      components.diagnostics(self.div)
    end

    local lines = vim.split(self.div:render(), "\n")
    if self.tick ~= this_tick then return end

    self.msg = lines

    for parent_id, _ in pairs(self.parent_infos) do
      infoview._info_by_id[parent_id]:render()
    end
  end)()
end

--- Update the info contents appropriately for Lean 4 or 3.
--- Normally will be called on each CursorMoved for a buffer containing Lean.
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
---@param id number
function infoview.__was_closed(id)
  infoview._by_id[id]:close()
end

--- Enable and open the infoview across all Lean buffers.
function infoview.enable(opts)
  options = vim.tbl_extend("force", options._DEFAULTS, opts)
  set_augroup("LeanInfoviewInit", [[
    autocmd FileType lean3 lua require'lean.infoview'.make_buffer_focusable(vim.fn.expand('<afile>'))
    autocmd FileType lean lua require'lean.infoview'.make_buffer_focusable(vim.fn.expand('<afile>'))
  ]])
end

--- Configure the infoview to update when this buffer is active.
function infoview.make_buffer_focusable(name)
  local bufnr = vim.fn.bufnr(name)
  if bufnr == -1 then return end
  if bufnr == vim.api.nvim_get_current_buf() then
    -- because FileType can happen after BufEnter
    infoview.maybe_autoopen() infoview.__update()
    infoview.get_current_infoview():focus_on_current_buffer()
  end

  -- WinEnter is necessary for the edge case where you have
  -- a file open in a tab with an infoview and move to a
  -- new window in a new tab with that same file but no infoview
  set_augroup("LeanInfoviewSetFocus", string.format([[
    autocmd BufEnter <buffer=%d> lua require'lean.infoview'.maybe_autoopen() require'lean.infoview'.__update()
    autocmd BufEnter,WinEnter <buffer=%d> lua if require'lean.infoview'.get_current_infoview()]] ..
    [[ then require'lean.infoview'.get_current_infoview():focus_on_current_buffer() end
  ]], bufnr, bufnr), 0)
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
