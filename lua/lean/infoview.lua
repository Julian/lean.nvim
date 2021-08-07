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
local options = { _DEFAULTS = { autoopen = true, width = 50, autopause = false } }

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

function Info:new()
  local new_info = {
    id = #infoview._info_by_id + 1,
    bufnr = vim.api.nvim_create_buf(false, true),
    pin = Pin:new(options.autopause)
  }
  new_info.pin:add_parent_info(new_info)
  table.insert(infoview._info_by_id, new_info)

  self.__index = self
  setmetatable(new_info, self)

  vim.api.nvim_buf_set_name(new_info.bufnr, "lean://info/" .. new_info.id)
  vim.api.nvim_buf_set_option(new_info.bufnr, 'filetype', 'leaninfo')

  return new_info
end

local paused_txt = "[PAUSED]"

--- Update this info's physical contents.
function Info:render()
  local function render_pin(pin, current)
    local pin_lines = {}

    local header
    if not current then
      header = "-- PIN " .. tostring(pin.id) .. (pin.paused and " " .. paused_txt or "")
    elseif pin.paused then
      header = "-- " .. paused_txt
    end

    if not current and pin.position_params then
      local bufnr = vim.fn.bufnr(vim.uri_to_fname(pin.position_params.textDocument.uri))
      local filename
      if bufnr ~= -1 then
        filename = vim.fn.bufname(bufnr)
      else
        filename = pin.position_params.textDocument.uri
      end
      header = header .. (": file %s at line %d, character %d"):format(filename,
        pin.position_params.position.line + 1, pin.position_params.position.character + 1)
    end

    if header then table.insert(pin_lines, header) end
    if not pin.msg or vim.tbl_isempty(pin.msg) then
      vim.list_extend(pin_lines, _NOTHING_TO_SHOW)
    else
      vim.list_extend(pin_lines, pin.msg)
    end

    return pin_lines
  end

  local lines = render_pin(self.pin, true)

  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, lines)
  -- HACK: This shouldn't really do anything, but I think there's a neovim
  --       display bug. See #27 and neovim/neovim#14663. Specifically,
  --       as of NVIM v0.5.0-dev+e0a01bdf7, without this, updating a long
  --       infoview with shorter contents doesn't properly redraw.
  vim.api.nvim_buf_call(self.bufnr, vim.fn.winline)
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', false)
end

function Pin:new(paused)
  local new_pin = {id = #infoview._pin_by_id + 1, parent_infos = {}, paused = paused, tick = 0}
  table.insert(infoview._pin_by_id, new_pin)

  self.__index = self
  setmetatable(new_pin, self)

  return new_pin
end

function Pin:add_parent_info(info)
  self.parent_infos[info.id] = true
end

function Pin:_set_position_params(params)
  self.position_params = params
end

--- Update this pin's current position.
function Pin:set_position_params(params)
  self:_set_position_params(params)
  self:update()
end

function Pin:toggle_pause() if not self.paused then self:pause() else self:unpause() end end

function Pin:unpause()
  if not self.paused then return end
  self.paused = false
  self:update()
end

function Pin:pause()
  if self.paused then return end
  self.paused = true
  self:update()
end

function Pin:update(force)
  a.void(function()
    if force or not self.paused then
      self:_update()
    end

    for parent_id, _ in pairs(self.parent_infos) do
      infoview._info_by_id[parent_id]:render()
    end
  end)()
end

local plain_goal = a.wrap(leanlsp.plain_goal, 3)
local plain_term_goal = a.wrap(leanlsp.plain_term_goal, 3)

local wait_timer = a.wrap(vim.loop.timer_start, 4)

--- async function to update this pin's contents given the current position.
function Pin:_update()
  self.tick = (self.tick + 1) % 1000
  local this_tick = self.tick

  wait_timer(vim.loop.new_timer(), 100, 0)
  a.util.scheduler()
  if self.tick ~= this_tick then return end

  if not self.position_params then
    self.msg = {"Pin position invalidated."}
    return
  end

  local params = vim.deepcopy(self.position_params)

  local buf = vim.fn.bufnr(vim.uri_to_fname(self.position_params.textDocument.uri))
  if buf == -1 then
    self.msg = {"No corresponding buffer found."}
    return
  end

  local lines

  if vim.api.nvim_buf_get_option(buf, "ft") == "lean3" then
    lines = lean3.update_infoview(buf, params)
  else
    if require"lean.progress".is_processing_at(params) then
      lines = {"Processing file..."}
    else
      local _, _, goal = plain_goal(params, buf)
      if self.tick ~= this_tick then return end

      local _, _, term_goal = plain_term_goal(params, buf)
      if self.tick ~= this_tick then return end

      lines = components.goal(goal)
      if not vim.tbl_isempty(lines) then table.insert(lines, '') end
      vim.list_extend(lines, components.term_goal(term_goal))
      vim.list_extend(lines, components.diagnostics())
    end
  end
  if self.tick ~= this_tick then return end

  self.msg = lines
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

--- Update the info contents appropriately for Lean 4 or 3.
--- Normally will be called on each CursorHold for a buffer containing Lean.
function infoview.__update()
  infoview.get_current_infoview().info.pin:set_position_params(vim.lsp.util.make_position_params())
end

--- Update pins corresponding to the given $/lean/fileProgress parameters.
function infoview.__update_progress(params)
  if infoview.enabled then
    for _, pin in pairs(infoview._pin_by_id) do
      if pin.position_params and pin.position_params.textDocument.uri == params.textDocument.uri then
        pin:update()
      end
    end
  end
end

--- Update pins position according to the given textDocument/didChange parameters.
function infoview.__update_pin_positions(params)
  for _, pin in pairs(infoview._pin_by_id) do
    if not pin.position_params or not pin.position_params.textDocument.uri == params.textDocument.uri then
      goto next_pin
    end

    local pos = pin.position_params.position
    local new_pos = require'lean._util'.update_position(pos, params.contentChanges)

    if not vim.deep_equal(pos, new_pos) then
      if new_pos then
        local new_params = vim.deepcopy(pin.position_params)
        new_params.position = new_pos
        pin:_set_position_params(new_params)
        vim.schedule_wrap(function() pin:update() end)()
      else
        pin:_set_position_params(nil)
        vim.schedule_wrap(function() pin:update() end)()
      end
    end

    ::next_pin::
  end
end

--- Enable and open the infoview across all Lean buffers.
function infoview.enable(opts)
  options = vim.tbl_extend("force", options._DEFAULTS, opts)
  infoview.enabled = true
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

--- Set whether a new pin is automatically paused.
function infoview.set_autopause(autopause)
  options.autopause = autopause
end

--- Open an infoview for the current buffer if it isn't already open.
function infoview.maybe_autoopen()
  local tabpage = vim.api.nvim_win_get_tabpage(0)
  if not infoview._by_tabpage[tabpage] then
    infoview._by_tabpage[tabpage] = Infoview:new(options.width, options.autoopen)
  end
end

return infoview
