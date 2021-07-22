local components = require('lean.infoview.components')
local lean3 = require('lean.lean3')
local leanlsp = require('lean.lsp')
local is_lean_buffer = require('lean').is_lean_buffer
local set_augroup = require('lean._util').set_augroup

local infoview = { _by_id = {} }
local options = { _DEFAULTS = { autoopen = true, width = 50, autoclose = true} }

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
local Infoview = {}

--- Get the ID of the infoview corresponding to the current window.
local function get_id()
  return vim.api.nvim_win_get_tabpage(0)
end

--- Get the infoview corresponding to the current window.
function infoview.get_current_infoview()
  return infoview._by_id[get_id()]
end

--- Create a new infoview.
---@param id number: the new ID associated with the infoview
---@param width number: the width of the new infoview
---@param open boolean: whether to open the infoview after initializing
function Infoview:new(id, width, open)
  local new_infoview = {id = id, width = width}

  -- a set with a counter method
  new_infoview.lean_windows = {}
  setmetatable(new_infoview.lean_windows, { __index = {
    get_count = function()
      local count = 0
      for _, _ in pairs(new_infoview.lean_windows) do count = count + 1 end
      return count
    end}})

  self.__index = self
  setmetatable(new_infoview, self)

  if not open then new_infoview:close() else new_infoview:open() end

  return new_infoview
end

--- Open this infoview if it isn't already open
function Infoview:open()
  if self.is_open then return vim.deepcopy(self) end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, "lean://infoview/" .. self.id)
  for name, value in pairs(_DEFAULT_BUF_OPTIONS) do
    vim.api.nvim_buf_set_option(bufnr, name, value)
  end

  local window_before_split = vim.api.nvim_get_current_win()

  vim.cmd("botright " .. self.width .. "vsplit")
  vim.cmd(string.format("buffer %d", bufnr))
  local window = vim.api.nvim_get_current_win()
  for name, value in pairs(_DEFAULT_WIN_OPTIONS) do
    vim.api.nvim_win_set_option(window, name, value)
  end
  -- Make sure we notice even if someone manually :q's the infoview window.
  set_augroup("LeanInfoviewClose", string.format([[
    autocmd WinClosed <buffer> lua require'lean.infoview'._by_id[%d]:close()
  ]], self.id), 0)

  vim.api.nvim_set_current_win(window_before_split)

  self.bufnr = bufnr
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
  self.bufnr = nil
  self.window = nil
  self.is_open = false

  self:focus_on_current_buffer()
end

--- Toggle this infoview being open.
function Infoview:toggle()
  if self.is_open then self:close() else self:open() end
end

--- Set the currently active Lean buffer to update the infoview.
function Infoview:focus_on_current_buffer()
  if not is_lean_buffer() then return end
  if self.is_open then
    set_augroup("LeanInfoviewUpdate", string.format([[
      autocmd CursorHold <buffer> lua require'lean.infoview'.infoview._by_id[%d]:update()
      autocmd CursorHoldI <buffer> lua require'lean.infoview'.infoview._by_id[%d]:update()
    ]], self.id, self.id), 0)
  else
    set_augroup("LeanInfoviewUpdate", "", 0)
  end
  self.lean_windows[vim.api.nvim_get_current_win()] = true
end

-- Clears the given window, possibly autoclosing this infoview if it was the last remaining one.
function Infoview:__clear_win(win, do_not_close)
  self.lean_windows[win] = nil
  if not do_not_close and options.autoclose and self.lean_windows.get_count() == 0 then self:close() end
end

--- Update this infoview's contents given the current position.
function Infoview:update()
  local update = vim.opt.filetype:get() == "lean3" and lean3.update_infoview or function(set_lines)
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
  update(function(lines)
    self.msg = lines
    self:render()
  end)
end

--- Update this infoview's physical contents.
function Infoview:render()
  if not self.is_open then return end
  local lines = self.msg

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

--- Retrieve the contents of the infoview as a table.
function Infoview:get_lines(start_line, end_line)
  if not self.is_open then return end

  start_line = start_line or 0
  end_line = end_line or -1
  return vim.api.nvim_buf_get_lines(self.bufnr, start_line, end_line, true)
end

--- Retrieve the current combined contents of the infoview as a string.
function Infoview:get_contents()
  if not self.is_open then return end

  return table.concat(self:get_lines(), "\n")
end

--- Is the infoview not showing anything?
function Infoview:is_empty()
  if not self.is_open then return end

  return vim.deep_equal(self:get_lines(), _NOTHING_TO_SHOW)
end

--- Close all open infoviews (across all tabs).
function infoview.close_all()
  for _, each in pairs(infoview._by_id) do
    each:close()
  end
end

--- Enable and open the infoview across all Lean buffers.
function infoview.enable(opts)
  options = vim.tbl_extend("keep", opts, options._DEFAULTS)
  set_augroup("LeanInfoviewInit", [[
    autocmd FileType lean3 lua require'lean.infoview'.__make_buffer_focusable()
    autocmd FileType lean lua require'lean.infoview'.__make_buffer_focusable()
  ]])
end

local __last_win

-- When a lean buffer associated with this infoview BufLeave's, we may want to update lean_windows.
function infoview.__lean_buffer_left()
  __last_win = vim.api.nvim_get_current_win()
  -- BufEnter is always triggered after BufLeave
  vim.cmd(string.format([[ autocmd BufEnter * ++once lua require'lean.infoview'.__lean_buffer_left_post(%d) ]],
    get_id()))
end

-- Actually determines whether to update lean_windows after the inevitable BufEnter following __lean_buffer_left.
-- TODO: Ideally this would be a local function to __lean_buffer_left but sadly neovim doesn't
-- have very good Lua autocmd integration yet :(
function infoview.__lean_buffer_left_post(id)
  -- if the original window no longer shows a lean buffer, remove it from the list
  if not (vim.api.nvim_win_is_valid(__last_win) and is_lean_buffer(vim.api.nvim_win_get_buf(__last_win)))
  then
    if infoview._by_id[id] then infoview._by_id[id]:__clear_win(__last_win) end
  end
  __last_win = nil
end

--- Configure the infoview to update when this buffer is active.
function infoview.__make_buffer_focusable()
  local bufenter  = [[autocmd BufEnter <buffer> lua require'lean.infoview'.__maybe_autoopen() ]] ..
                    [[require'lean.infoview'.get_current_infoview():focus_on_current_buffer()]]
  local bufleave  = [[autocmd BufLeave <buffer> lua require'lean.infoview'.__lean_buffer_left()]]
  local winclosed = [[autocmd WinClosed <buffer> lua if require'lean.infoview'.get_current_infoview() ]] ..
                    [[then require'lean.infoview'.get_current_infoview():__clear_win]] ..
                    [[(tonumber(vim.fn.expand('<afile>')), true) end]]
  -- WinEnter is necessary for the edge case where you have
  -- a file open in a tab with an infoview and move to a
  -- new window in a new tab with that same file but no infoview
  local winenter = [[autocmd WinEnter <buffer> lua if require'lean.infoview'.get_current_infoview() ]] ..
                   [[then require'lean.infoview'.get_current_infoview():focus_on_current_buffer() end]]
  set_augroup("LeanInfoviewSetFocus", table.concat({bufenter, bufleave, winclosed, winenter}, "\n"), 0)
end

--- Set whether a new infoview is automatically opened when entering Lean buffers.
function infoview.set_autoopen(autoopen)
  options.autoopen = autoopen
end

--- Set whether an infoview is automatically closed when leaving from its last associated Lean file.
function infoview.set_autoclose(autoclose)
  options.autoclose = autoclose
end

--- Open an infoview for the current buffer if it isn't already open.
function infoview.__maybe_autoopen()
  local id = get_id()
  if not infoview._by_id[id] then infoview._by_id[id] = Infoview:new(id, options.width, options.autoopen) end
end

return infoview
