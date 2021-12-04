local components = require'lean.infoview.components'
local lean3 = require'lean.lean3'
local leanlsp = require'lean.lsp'
local is_lean_buffer = require'lean'.is_lean_buffer
local util = require'lean._util'
local set_augroup = util.set_augroup
local a = require'plenary.async'
local html = require'lean.html'
local rpc = require'lean.rpc'
local protocol = require'vim.lsp.protocol'

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
  --- Whether to print additional debug information in the infoview.
  ---@type boolean
  debug = false,
}
local options = {
  _DEFAULTS = {
    width = 50,
    height = 20,

    autoopen = true,
    autopause = false,
    indicators = "auto",
    lean3 = { show_filter = true, mouse_events = false },
    show_processing = true,
    use_widget = true,

    mappings = {
      ["K"] = [[click]],
      ["<CR>"] = [[click]],
      ["I"] = 'mouse_enter',
      ["i"] = 'mouse_leave',
      ["<Esc>"] = 'clear_all',
      ["C"] = 'clear_all',
      ["<LocalLeader><Tab><Tab>"] = [[goto_last_window]]
    }
  }
}

--- An individual pin.
---@class Pin
---@field id number
---@field parent_infos table<number, boolean>
---@field use_widget boolean
---@field data_div Div
---@field ui_div Div
---@field render_header Div
---@field div Div
---@field bufdiv BufDiv
---@field ticker table
local Pin = {next_id = 1}

--- An individual info.
---@class Info
---@field id number
---@field parent_infoviews table<number, boolean>
---@field pin Pin
---@field diff_pin Pin
---@field pins Pin[]
---@field pins_set table<number, Pin> @mapping from pin ID to Pin corresponding to `self.pins`
---@field win_event_disable boolean
local Info = {}

--- A "view" on an info (i.e. window).
---@class Infoview
---@field id number
---@field width number
---@field height number
---@field info Info
---@field window integer @main pin window
---@field diff_win number @diff pin window
---@field pins_wins table<number, number> @mapping from pin IDs to pin windows
---@field orientation "vertical"|"horizontal"
local Infoview = {}

local pin_hl_group = "LeanNvimPin"
vim.highlight.create(pin_hl_group, {
  cterm = 'underline',
  ctermbg = '3',
  gui   = 'underline',
}, true)

local diff_pin_hl_group = "LeanNvimDiffPin"
vim.highlight.create(diff_pin_hl_group, {
  cterm = 'underline',
  ctermbg = '7',
  gui   = 'underline',
}, true)

--- Enables printing of extra debugging information in the infoview.
function infoview.enable_debug()
  infoview.debug = true
end

--- Get the infoview corresponding to the current window.
---@return Infoview
function infoview.get_current_infoview()
  return infoview._by_tabpage[vim.api.nvim_win_get_tabpage(0)]
end

--- Create a new infoview.
---@param open boolean: whether to open the infoview after initializing
---@return Infoview
function Infoview:new(open)
  local new_infoview = {
    id = #infoview._by_id + 1,
    width = options.width,
    height = options.height,
    diff_open = false,
    info = Info:new(),
    pins_wins = {}
  }
  new_infoview.info:add_parent_infoview(new_infoview)
  table.insert(infoview._by_id, new_infoview)
  self.__index = self
  setmetatable(new_infoview, self)

  if not open then new_infoview:close() else new_infoview:open() end

  return new_infoview
end

--- Open this infoview if it isn't already open
function Infoview:open()
  if self.is_open then return end

  local window_before_split = vim.api.nvim_get_current_win()

  local win_width = vim.api.nvim_win_get_width(window_before_split)
  local win_height = vim.api.nvim_win_get_height(window_before_split)

  local ch_aspect_ratio = 2.5 -- characters are 2.5x taller than they are wide
  if win_width > ch_aspect_ratio * win_height then -- vertical split
    self.orientation = "vertical"
  else -- horizontal split
    self.orientation = "horizontal"
  end

  self.is_open = true

  local window = self:__open_win("botright")
  self.window = window

  vim.api.nvim_win_set_buf(self.window, self.info.pin.bufdiv.buf)
  -- Set the filetype now. Any earlier, and only buffer-local options will be
  -- properly set in the infoview, since the buffer isn't actually shown in a
  -- window until we run :buffer above.
  vim.api.nvim_buf_set_option(self.info.pin.bufdiv.buf, 'filetype', 'leaninfo')

  self.info:focus_on_current_buffer()

  self:__refresh()
end

function Infoview:__refresh()
  if not self.is_open then return end

  self:__refresh_diff_win()
  self:__refresh_pins_win()
  self:__refresh_bufs()
  self:__refresh_diff()
  self:__refresh_pins()
end

--- API for opening an auxilliary window relative to
--- the current infoview window, considering `self.orientation`.
--- @param orientation string @"leftabove" or "rightbelow"
--- @param win number @window to split from, defaults to `self.window`
--- @param flip boolean|nil @whether to split in the opposite direction of `self.orientation`
--- @param raw boolean|nil @whether to do a raw split (ignoring `self.width` and `self.height`)
--- @return number @new window handle or nil if the infoview is closed
function Infoview:__open_win(orientation, win, flip, raw)
  if not self.is_open then return end
  win = win or self.window

  self.info.win_event_disable = true
  local window_before_split = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(win)

  local vertical = self.orientation == "vertical"
  if flip then vertical = not vertical end

  if vertical then
    if raw then
      vim.cmd(orientation .. " vsplit")
    else
      vim.cmd(orientation .. " " .. self.width .. "vsplit")
      vim.cmd("vertical resize " .. self.width)
    end
  else
    if raw then
      vim.cmd(orientation .. " split")
    else
      vim.cmd(orientation .. " " .. self.height .. "split")
      vim.cmd("resize " .. self.height)
    end
  end
  vim.api.nvim_command("setlocal winfixwidth")

  local new_win = vim.api.nvim_get_current_win()

  vim.api.nvim_set_current_win(window_before_split)
  self.info.win_event_disable = false

  return new_win
end

--- Either open or close a pins window for this infoview depending on whether its info has pins.
function Infoview:__refresh_pins_win()
  if not self.is_open then return end

  local last_pin_win

  -- open windows for any unopened pins
  for _, pin in ipairs(self.info.pins) do
    if not self.pins_wins[pin.id] then
      if not last_pin_win then
        last_pin_win = self:__open_win("rightbelow")
      else
        last_pin_win = self:__open_win("rightbelow", last_pin_win, true, true)
      end
      vim.api.nvim_win_set_buf(last_pin_win, pin.bufdiv.buf)
      vim.api.nvim_buf_set_option(pin.bufdiv.buf, 'filetype', 'leaninfo')
      self.pins_wins[pin.id] = last_pin_win
    else
      last_pin_win = self.pins_wins[pin.id]
    end
  end

  -- close windows for any pins that are no longer in the current info
  for pin_id, win in pairs(vim.deepcopy(self.pins_wins)) do
    self.info.win_event_disable = true
    if not self.info.pins_set[pin_id] then
      if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      self.pins_wins[pin_id] = nil
    end
    self.info.win_event_disable = false
  end
end

function Infoview:__refresh_pins()
  -- make sure they aren't in diff mode, because splitting a diff window results in another diff window
  self.info.win_event_disable = true
  for _, win in pairs(vim.deepcopy(self.pins_wins)) do
    vim.api.nvim_win_call(win, function() vim.api.nvim_command"diffoff" end)
  end
  self.info.win_event_disable = false
end

--- Either open or close a diff window for this infoview depending on whether its info has a diff_pin.
function Infoview:__refresh_diff_win()
  if not self.is_open then return end

  if self.info.diff_pin and not self.diff_win then
    self.diff_win = self:__open_win("leftabove")
    vim.api.nvim_win_set_buf(self.diff_win, self.info.diff_pin.bufdiv.buf)
    vim.api.nvim_buf_set_option(self.info.diff_pin.bufdiv.buf, 'filetype', 'leaninfo')
  end

  if not self.info.diff_pin and self.diff_win then
    self.info.win_event_disable = true
    if vim.api.nvim_win_is_valid(self.diff_win) then
      vim.api.nvim_win_close(self.diff_win, true)
    end
    self.info.win_event_disable = false
    self.diff_win = nil
    return
  end
end

function Infoview:__refresh_diff()
  self.info.win_event_disable = true
  if self.info.diff_pin then
    for _, win in pairs({self.diff_win, self.window}) do
      vim.api.nvim_win_call(win, function()
        vim.api.nvim_command"diffthis"
        vim.api.nvim_command("set foldmethod=manual")
        vim.api.nvim_command("setlocal wrap")
      end)
    end
  else
    vim.api.nvim_win_call(self.window, function() vim.api.nvim_command"diffoff" end)
  end
  self.info.win_event_disable = false
end

--- Refresh the buffers in the windows in case the underlying Info has changed.
function Infoview:__refresh_bufs()
  self.info.win_event_disable = true
  if self.window then
    if vim.api.nvim_win_get_buf(self.window) ~= self.info.pin.bufdiv.buf then
      vim.api.nvim_win_set_buf(self.window, self.info.pin.bufdiv.buf)
      vim.api.nvim_buf_set_option(self.info.pin.bufdiv.buf, 'filetype', 'leaninfo')
    end
  end

  if self.info.diff_pin and self.diff_win then
    if vim.api.nvim_win_get_buf(self.diff_win) ~= self.info.diff_pin.bufdiv.buf then
      vim.api.nvim_win_set_buf(self.diff_win, self.info.diff_pin.bufdiv.buf)
      vim.api.nvim_buf_set_option(self.info.pin.bufdiv.buf, 'filetype', 'leaninfo')
    end
  end

  -- close windows for any pins that are no longer in the current info
  for pin_id, win in pairs(vim.deepcopy(self.pins_wins)) do
    local pin = infoview._pin_by_id[pin_id]

    if vim.api.nvim_win_get_buf(win) ~= pin.bufdiv.buf then
      vim.api.nvim_win_set_buf(win, pin.bufdiv.buf)
      vim.api.nvim_buf_set_option(self.info.pin.bufdiv.buf, 'filetype', 'leaninfo')
    end
  end
  self.info.win_event_disable = false
end

--- Close this infoview.
function Infoview:close()
  if not self.is_open then
    -- in case it is nil
    self.is_open = false
    return
  end

  self.info.win_event_disable = true
  vim.api.nvim_win_close(self.window, true)
  if self.diff_win then
    vim.api.nvim_win_close(self.diff_win, true)
    self.diff_win = nil
  end
  for pin_id, win in pairs(vim.deepcopy(self.pins_wins)) do
    vim.api.nvim_win_close(win, true)
    self.pins_wins[pin_id] = nil
  end
  self.info.win_event_disable = false

  self.window = nil
  self.is_open = false

  self.info:focus_on_current_buffer()
end

--- Toggle this infoview being open.
function Infoview:toggle()
  if self.is_open then self:close() else self:open() end
end

--- Set the currently active Lean buffer to update the info.
function Info:focus_on_current_buffer()
  if not is_lean_buffer() then return end
  local is_open = false
  for parent_id, _ in pairs(self.parent_infoviews) do
    if infoview._by_id[parent_id].is_open then
      is_open = true
      break
    end
  end

  if is_open then
    set_augroup("LeanInfoviewUpdate", string.format([[
      autocmd CursorMoved <buffer> lua require'lean.infoview'.__update(%d)
      autocmd CursorMovedI <buffer> lua require'lean.infoview'.__update(%d)
    ]], self.id, self.id), 0)
  else
    set_augroup("LeanInfoviewUpdate", "", 0)
  end
end

---@return Info
function Info:new()
  local new_info = {
    id = #infoview._info_by_id + 1,
    pins = {},
    pins_set = {},
    parent_infoviews = {},
    win_event_disable = false
  }
  table.insert(infoview._info_by_id, new_info)

  self.__index = self
  setmetatable(new_info, self)
  self = new_info

  self:__new_current_pin()

  self:render()

  return self
end

---@param _infoview Infoview
function Info:add_parent_infoview(_infoview)
  self.parent_infoviews[_infoview.id] = true
end

function Info:__new_current_pin()
  self.pin = Pin:new(options.autopause, options.use_widget)
  self.pin:__new_bufdiv()
  self.pin:add_parent_info(self)

  -- Show/hide current pin extmark when entering/leaving infoview.
  set_augroup("LeanInfoviewShowPin", string.format([[
    autocmd WinEnter <buffer=%d> lua require'lean.infoview'.__show_curr_pin(%d)
    autocmd WinLeave <buffer=%d> lua require'lean.infoview'.__hide_curr_pin(%d)
  ]], self.pin.bufdiv.buf, self.id, self.pin.bufdiv.buf, self.id), self.pin.bufdiv.buf)

  -- Make sure we notice even if someone manually :q's the infoview window.
  set_augroup("LeanInfoviewClose", string.format([[
    autocmd WinClosed <buffer=%d> lua require'lean.infoview'.__was_closed(%d)
  ]], self.pin.bufdiv.buf, self.id), self.pin.bufdiv.buf)
end

function Info:add_pin()
  local new_params = vim.deepcopy(self.pin.position_params)
  table.insert(self.pins, self.pin)
  self.pins_set[self.pin.id] = self.pin
  set_augroup("LeanInfoviewShowPin", "", self.pin.bufdiv.buf)
  -- Make sure we notice even if someone manually :q's this pin's window.
  set_augroup("LeanInfoviewClose", string.format([[
    autocmd WinClosed <buffer=%d> lua require'lean.infoview'.__pin_was_closed(%d, %d)
  ]], self.pin.bufdiv.buf, self.id, self.pin.id), self.pin.bufdiv.buf)
  self:maybe_show_pin_extmark(tostring(self.pin.id))
  self.pin.render_header = true
  self.pin:render()

  self:__new_current_pin()
  self.pin:move(new_params)

  self:render()
end

function Info:clear_pin(pin_id)
  local idx
  for this_idx, pin in ipairs(self.pins) do
    if pin.id == pin_id then idx = this_idx break end
  end
  if not idx then return end

  local pin = self.pins[idx]

  table.remove(self.pins, idx)
  self.pins_set[pin_id] = nil

  self:render()

  pin:remove_parent_info(self)
end

function Info:set_diff_pin(params)
  if not self.diff_pin then
    self.diff_pin = Pin:new(options.autopause, options.use_widget)
    self.diff_pin:__new_bufdiv()
    self.diff_pin:add_parent_info(self)
    self.diff_pin:show_extmark(nil, diff_pin_hl_group)

    -- Make sure we notice even if someone manually :q's the diff window.
    set_augroup("LeanInfoviewClose", string.format([[
      autocmd WinClosed <buffer=%d> lua require'lean.infoview'.__diff_was_closed(%d)
    ]], self.diff_pin.bufdiv.buf, self.id), self.diff_pin.bufdiv.buf)
  end

  self.diff_pin:move(params)

  self:render()
end

--- Close all parent infoviews.
function Info:clear()
  for parent_id, _ in pairs(self.parent_infoviews) do
    infoview._by_id[parent_id]:close()
  end
end

function Info:clear_pins()
  -- FIXME this is n^2 in the number of pins
  local ids = {}
  for pin_id, _ in pairs(self.pins_set) do table.insert(ids, pin_id) end
  for _, pin_id in pairs(ids) do self:clear_pin(pin_id) end
end

function Info:clear_diff_pin()
  if not self.diff_pin then return end
  local diff_pin = self.diff_pin
  self.diff_pin = nil

  self:render()

  diff_pin:remove_parent_info(self)
end

--- Show a pin extmark if it is appropriate based on configuration.
function Info:maybe_show_pin_extmark(...)
  if not options.indicators or options.indicators == "never" then return end
  -- self.pins is apparently all *other* pins, so we check it's empty
  if options.indicators == "auto" and #self.pins == 0 then return end
  self.pin:show_extmark(...)
end

--- Set the current window as the last window used to update this Info.
function Info:set_last_window()
  self.last_window = vim.api.nvim_get_current_win()
  self.last_buf = vim.api.nvim_get_current_buf()
end

--- Update this info's physical contents.
function Info:render()
  self:__refresh_parents()

  collectgarbage()
end

--- Update the diff pin to use the current pin's positon params if they are valid,
--- and the provided params if they are not.
function Info:__update_auto_diff_pin(params)
  if self.pin.position_params and util.position_params_valid(self.pin.position_params) then
    -- update diff pin to previous position
    self:set_diff_pin(self.pin.position_params)
  elseif params then
    -- if previous position invalid, use current position
    self:set_diff_pin(params)
  end
end

--- Move the current pin to the specified location.
function Info:move_pin(params)
  if self.auto_diff_pin then self:__update_auto_diff_pin(params) end
  self.pin:move(params)
end

--- Toggle auto diff pin mode.
--- @param clear boolean @clear the pin when disabling auto diff pin mode?
function Info:toggle_auto_diff_pin(clear)
  if self.auto_diff_pin then
    self.auto_diff_pin = false
    if clear then self:clear_diff_pin() end
  else
    self.auto_diff_pin = true
    -- only update the diff pin if there isn't already one
    if not self.diff_pin then self:__update_auto_diff_pin() end
  end
end

--- Refresh parent infoview diff windows.
function Info:__refresh_parents()
  for parent_id, _ in pairs(self.parent_infoviews) do
    infoview._by_id[parent_id]:__refresh()
  end
end

---@return Pin
function Pin:new(paused, use_widget)
  local new_pin = {id = self.next_id, parent_infos = {}, paused = paused,
    ticker = util.Ticker:new(),
    data_div = html.Div:new("", "pin-data", nil),
    div = html.Div:new("", "pin", nil), use_widget = use_widget,
    ui_div = html.Div:new("", "pin_ui", nil)}
  self.next_id = self.next_id + 1
  infoview._pin_by_id[new_pin.id] = new_pin

  self.__index = self
  setmetatable(new_pin, self)

  return new_pin
end

--- Set whether this pin uses a widget or a plain goal/term goal.
function Pin:set_widget(use_widget)
  self.use_widget = use_widget
  self:update()
end

---@param info Info
function Pin:add_parent_info(info)
  self.parent_infos[info.id] = true
end

local extmark_ns = vim.api.nvim_create_namespace("LeanNvimPinExtmarks")

function Pin:_teardown()
  if self.extmark then vim.api.nvim_buf_del_extmark(self.extmark_buf, extmark_ns, self.extmark) end
  if self.bufdiv then self.bufdiv:buf_close() end
  infoview._pin_by_id[self.id] = nil
end

function Pin:remove_parent_info(info)
  self.parent_infos[info.id] = nil
  if vim.tbl_isempty(self.parent_infos) then self:_teardown() end
end

--- Update this pin's current position.
function Pin:set_position_params(params, delay, lean3_opts)
  local old_params = self.position_params
  self.position_params = params

  lean3_opts = vim.tbl_extend("keep", lean3_opts or {}, {changed = not vim.deep_equal(params, old_params)})

  self:update_extmark()
  self:update(false, delay, nil, lean3_opts)
end

--- Update pin extmark based on position, used when resetting pin position.
function Pin:update_extmark()
  local params = self.position_params
  if not params then return end

  local buf = vim.fn.bufnr(vim.uri_to_fname(params.textDocument.uri))

  if buf ~= -1 then
    local line = params.position.line
    local buf_line = vim.api.nvim_buf_get_lines(buf, line, line + 1, false)[1]
    local col = buf_line and vim.str_byteindex(buf_line, params.position.character) or 0
    local end_col = buf_line and ((col < #buf_line) and
      vim.str_byteindex(buf_line, params.position.character + 1) or col) or 0

    self.extmark = vim.api.nvim_buf_set_extmark(buf, extmark_ns,
      line, col,
      {
        id = self.extmark;
        end_col = end_col;
        hl_group = self.extmark_hl_group;
        virt_text = self.extmark_virt_text;
        virt_text_pos = "right_align";
      })
    self.extmark_buf = buf
  end
end

--- Update pin position based on extmark, used when changing text.
function Pin:update_position(delay, lean3_opts)
  local extmark = self.extmark
  if not extmark then return end

  local buf = self.extmark_buf
  if buf == -1 then return end

  local extmark_pos = vim.api.nvim_buf_get_extmark_by_id(buf, extmark_ns, extmark, {})

  local pos = self.position_params.position
  local new_pos = vim.deepcopy(pos)

  new_pos.line = extmark_pos[1]
  local buf_line = vim.api.nvim_buf_get_lines(buf, new_pos.line, new_pos.line + 1, false)[1]
  new_pos.character = buf_line and vim.str_utfindex(buf_line, extmark_pos[2]) or new_pos.character

  local new_params = vim.deepcopy(self.position_params)
  new_params.position = new_pos
  self:set_position_params(new_params, delay, lean3_opts)
end

function Pin:toggle_pause() if not self.paused then self:pause() else self:unpause() end end

function Pin:show_extmark(name, hlgroup)
  self.extmark_hl_group = hlgroup or pin_hl_group
  if name then
    self.extmark_virt_text = {{"← " .. (name or tostring(self.id)), "Comment"}}
  else
    self.extmark_virt_text = nil
  end
  self:update_extmark()
end

function Pin:hide_extmark()
  self.extmark_hl_group = nil
  self.extmark_virt_text = nil
  self:update_extmark()
end

function Pin:unpause()
  if not self.paused then return end
  self.paused = false
  self:update()
end

function Pin:pause()
  if self.paused then return end
  self.paused = true

  self.data_div = self.data_div:dummy_copy()
  if not self:set_loading(false) then
    self.div.divs = { self.data_div }
    self:render()
  end

  -- abort any pending requests
  self.ticker:lock()
end

-- Triggered when manually moving a pin.
function Pin:move(params)
  self:set_position_params(params)
end

function Pin:__new_bufdiv()
  local function mk_buf(name, listed)
    local bufnr = vim.api.nvim_create_buf(listed or false, true)
    vim.api.nvim_buf_set_name(bufnr, name)
    return bufnr
  end
  self.bufdiv = html.BufDiv:new(mk_buf("lean://pin/" .. self.id, true), self.ui_div, options.mappings)

  self:render()

  self.ui_div.events = {
    goto_last_window = function()
      local curr_infoview = infoview.get_current_infoview()
      if curr_infoview and curr_infoview.info.last_window then
        vim.api.nvim_set_current_win(curr_infoview.info.last_window)
      end
    end
  }
end

function Pin:render()
  local header_div = html.Div:new("", "pin-header")
  if infoview.debug then
    header_div:insert_div("-- PIN " .. tostring(self.id), "pin-id-header")

    local function add_attribute(text, name)
      header_div:insert_div(" [" .. text .. "]", name .. "-attribute")
    end
    if self.paused then add_attribute("PAUSED", "paused") end
    if self.loading then add_attribute("LOADING", "loading") end
  end

  if self.render_header and self.position_params then
    local bufnr = vim.fn.bufnr(vim.uri_to_fname(self.position_params.textDocument.uri))
    local filename
    if bufnr ~= -1 then
      filename = vim.fn.bufname(bufnr)
    else
      filename = self.position_params.textDocument.uri
    end
    if not infoview.debug then
      header_div:insert_div("-- ", "pin-id-header")
    else
      header_div:insert_div(": ", "pin-header-separator")
    end
    local location_text = ("%s at %d:%d"):format(filename,
      self.position_params.position.line + 1, self.position_params.position.character + 1)
    header_div:insert_div(location_text, "pin-location")

    header_div.highlightable = true
    header_div.events = {
      click = function()
        local curr_infoview = infoview.get_current_infoview()
        if curr_infoview and curr_infoview.info.last_window then
          vim.api.nvim_set_current_win(curr_infoview.info.last_window)
          local uri_bufnr = vim.uri_to_bufnr(self.position_params.textDocument.uri)
          vim.api.nvim_set_current_buf(uri_bufnr)
          vim.api.nvim_win_set_cursor(0,
            { self.position_params.position.line + 1, self.position_params.position.character })
        end
      end
    }
  end
  if not header_div:is_empty() then
    header_div:insert_div("\n", "pin-header-end")
  end

  self.ui_div.divs = {}
  self.ui_div:add_div(header_div)
  if self.div then self.ui_div:add_div(self.div) end

  self.bufdiv:buf_render()
end

-- Indicate that the pin is either loading or done loading, if it isn't already set as such.
function Pin:set_loading(loading)
  if loading and not self.loading then
    self.div.divs = {}
    local data_div_copy = self.data_div:dummy_copy()

    self.div:add_div(data_div_copy)

    self.loading = true

    self:render()
    return true
  elseif not loading and self.loading then
    self.div.divs = {}
    self.div:add_div(self.data_div)

    self.loading = false

    self:render()
    return true
  end

  return false
end

function Pin:async_update(force, delay, _, lean3_opts)
  if not force and self.paused then return end

  local tick = self.ticker:lock()

  self:_update(force, delay, tick, lean3_opts)
  if not tick:check() then return end

  if not self:set_loading(false) then
    self:render()
  end
end

Pin.update = a.void(Pin.async_update)

function Pin:_update(force, delay, tick, lean3_opts)
  if self.position_params and (force or not self.paused) then
    return self:__update(tick, delay, lean3_opts)
  end
end

local plain_goal = a.wrap(leanlsp.plain_goal, 3)
local plain_term_goal = a.wrap(leanlsp.plain_term_goal, 3)

--- async function to update this pin's contents given the current position.
function Pin:__update(tick, delay, lean3_opts)
  delay = delay or 100

  self:set_loading(true)
  local new_data_div = html.Div:new("", "pin-data", nil)

  if delay > 0 then
    util.wait_timer(delay)
  end

  local params = self.position_params

  local buf = vim.fn.bufnr(vim.uri_to_fname(params.textDocument.uri))
  if buf == -1 then
    error("No corresponding buffer found for update.")
    return false
  end

  --- TODO if changes are currently being debounced for this buffer, add debounce timer delay
  do
    local line = params.position.line

    if vim.api.nvim_buf_get_option(buf, "ft") == "lean3" then
      lean3_opts = lean3_opts or {}
      lean3.update_infoview(self, new_data_div, buf, params,
        self.use_widget, lean3_opts, options.lean3, options.show_processing)
      goto finish
    end

    if require"lean.progress".is_processing_at(params) then
      if options.show_processing then
        new_data_div:insert_div("Processing file...", "processing-msg")
      end
      goto finish
    end

    self.sess = rpc.open(buf, params)
    if not tick:check() then return true end

    local goal_div
    if self.use_widget then
      local goal, err = self.sess:getInteractiveGoals(params)
      if not tick:check() then return true end
      if err and err.code == protocol.ErrorCodes.ContentModified then
        return self:__update(tick, delay, lean3_opts)
      end
      if not err then
        goal_div = components.interactive_goals(goal, self.sess)
      end
    end

    if not goal_div then
      local err, goal = plain_goal(params, buf)
      if not tick:check() then return true end
      if err and err.code == protocol.ErrorCodes.ContentModified then
        return self:__update(tick, delay, lean3_opts)
      end
      goal_div = components.goal(goal)
    end

    local term_goal_div
    if self.use_widget then
      local term_goal, err = self.sess:getInteractiveTermGoal(params)
      if not tick:check() then return true end
      if err and err.code == protocol.ErrorCodes.ContentModified then
        return self:__update(tick, delay, lean3_opts)
      end
      if not err then
        term_goal_div = components.interactive_term_goal(term_goal, self.sess)
      end
    end

    if not term_goal_div then
      local err, term_goal = plain_term_goal(params, buf)
      if not tick:check() then return true end
      if err and err.code == protocol.ErrorCodes.ContentModified then
        return self:__update(tick, delay, lean3_opts)
      end
      term_goal_div = components.term_goal(term_goal)
    end

    local goal_div_empty, term_goal_div_empty = goal_div:is_empty(), term_goal_div:is_empty()

    new_data_div:add_div(goal_div)
    if not goal_div_empty and not term_goal_div_empty then
      new_data_div:add_div(html.Div:new("\n\n", "plain_goal-term_goal-separator"))
    end
    new_data_div:add_div(term_goal_div)

    if goal_div_empty and term_goal_div_empty then
      new_data_div:add_div(html.Div:new("No info.", "no-tactic-term"))
    end

    local diagnostics_div
    if self.use_widget then
      local diags, err = self.sess:getInteractiveDiagnostics({ start = line, ['end'] = line + 1 })
      if not tick:check() then return true end
      if err and err.code == protocol.ErrorCodes.ContentModified then
        return self:__update(tick, delay, lean3_opts)
      end
      if not err then
        diagnostics_div = components.interactive_diagnostics(diags, line, self.sess)
      end
    end

    new_data_div:add_div(diagnostics_div or components.diagnostics(buf, line))

    if not tick:check() then return true end
  end

  new_data_div.events.clear_all = function(ctx) ---@param ctx DivEventContext
    vim.api.nvim_set_current_win(ctx.self.last_win)
    new_data_div:find(function (div) ---@param div Div
      if div.events.clear then div.events.clear(ctx) end
    end)
  end

  ::finish::
  self.data_div = new_data_div
  return true
end

--- Close all open infoviews (across all tabs).
function infoview.close_all()
  for _, each in pairs(infoview._by_id) do
    each:close()
  end
end

--- An infoview was closed, either directly via `Infoview.close` or manually.
--- Will be triggered via a `WinClosed` autocmd.
---@param id number @info id
function infoview.__was_closed(id)
  local info = infoview._info_by_id[id]
  if info.win_event_disable then return end
  info:clear()
end

--- An infoview diff window was closed.
--- Will be triggered via a `WinClosed` autocmd.
---@param id number @info id
function infoview.__diff_was_closed(id)
  local info = infoview._info_by_id[id]
  if info.win_event_disable then return end
  info:clear_diff_pin()
end

--- An infoview pins window was closed.
--- Will be triggered via a `WinClosed` autocmd.
---@param id number @info id
---@param pin_id number @pin id
function infoview.__pin_was_closed(id, pin_id)
  local info = infoview._info_by_id[id]
  if info.win_event_disable then return end
  info:clear_pin(pin_id)
end

--- An infoview was entered, show the extmark for the current pin.
--- Will be triggered via a `WinEnter` autocmd.
---@param id number @info id
function infoview.__show_curr_pin(id)
  local info = infoview._info_by_id[id]
  if info.win_event_disable then return end
  info:maybe_show_pin_extmark("current")
end

--- An infoview was left, hide the extmark for the current pin.
--- Will be triggered via a `WinLeave` autocmd.
---@param id number @info id
function infoview.__hide_curr_pin(id)
  local info = infoview._info_by_id[id]
  if info.win_event_disable then return end
  info.pin:hide_extmark()
end

--- Update the info contents appropriately for Lean 4 or 3.
--- Normally will be called on each CursorHold for a buffer containing Lean.
--- TODO perhaps this should be schedule_wrap'ed?
--- @param id number @info id
function infoview.__update(id)
  local info = id and infoview._info_by_id[id] or infoview.get_current_infoview().info
  if info.win_event_disable then return end

  if not is_lean_buffer() then return end
  info:set_last_window()
  pcall(info.move_pin, info, vim.lsp.util.make_position_params())
end

--- Update pins corresponding to the given URI.
function infoview.__update_event(uri)
  if infoview.enabled then
    for _, pin in pairs(infoview._pin_by_id) do
      if pin.position_params and pin.position_params.textDocument.uri == uri then
        pin:update()
      end
    end
  end
end

--- on_lines callback to update pins position according to the given textDocument/didChange parameters.
function infoview.__update_pin_positions(_, bufnr, _, _, _, _, _, _, _)
  for _, pin in pairs(infoview._pin_by_id) do
    if pin.position_params and pin.position_params.textDocument.uri == vim.uri_from_bufnr(bufnr) then
      vim.schedule_wrap(function() pin:update_position(500) end)()
    end
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
    infoview.__bufenter()
    infoview.get_current_infoview().info:focus_on_current_buffer()
  end

  -- WinEnter is necessary for the edge case where you have
  -- a file open in a tab with an infoview and move to a
  -- new window in a new tab with that same file but no infoview
  set_augroup("LeanInfoviewSetFocus", string.format([[
    autocmd BufEnter <buffer=%d> lua require'lean.infoview'.__bufenter()
    autocmd BufEnter,WinEnter <buffer=%d> lua if require'lean.infoview'.get_current_infoview()]] ..
    [[ then require'lean.infoview'.get_current_infoview().info:focus_on_current_buffer() end
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

local attached_buffers = {}

--- Callback when entering a Lean buffer.
function infoview.__bufenter()
  infoview.__maybe_autoopen()
  local bufnr = vim.api.nvim_get_current_buf()
  if not attached_buffers[bufnr] then
    vim.api.nvim_buf_attach(bufnr, false, {on_lines = infoview.__update_pin_positions;})
    attached_buffers[bufnr] = true
  end
  infoview.__update()
end

--- Open an infoview for the current buffer if it isn't already open.
function infoview.__maybe_autoopen()
  local tabpage = vim.api.nvim_win_get_tabpage(0)
  if not infoview._by_tabpage[tabpage] then
    infoview._by_tabpage[tabpage] = Infoview:new(options.autoopen)
  end
end

function infoview.open()
  infoview.__maybe_autoopen()
  infoview.get_current_infoview():open()
end

function infoview.toggle()
  local iv = infoview.get_current_infoview()
  if iv ~= nil then
    iv:toggle()
  else
    infoview.open()
  end
end

function infoview.pin_toggle_pause()
  local iv = infoview.get_current_infoview()
  if iv then iv.info.pin:toggle_pause() end
end

function infoview.add_pin()
  if not is_lean_buffer() then return end
  infoview.open()
  infoview.get_current_infoview().info:set_last_window()
  infoview.get_current_infoview().info:add_pin()
end

function infoview.set_diff_pin()
  if not is_lean_buffer() then return end
  infoview.open()
  infoview.get_current_infoview().info:set_last_window()
  infoview.get_current_infoview().info:set_diff_pin(vim.lsp.util.make_position_params())
end

function infoview.clear_pins()
  local iv = infoview.get_current_infoview()
  if iv ~= nil then
    iv.info:clear_pins()
  end
end

function infoview.clear_diff_pin()
  local iv = infoview.get_current_infoview()
  if iv ~= nil then
    iv.info:clear_diff_pin()
  end
end

function infoview.toggle_auto_diff_pin(clear)
  if not is_lean_buffer() then return end
  infoview.open()
  infoview.get_current_infoview().info:toggle_auto_diff_pin(clear)
end

function infoview.enable_widgets()
  local iv = infoview.get_current_infoview()
  if iv ~= nil then iv.info.pin:set_widget(true) end
end

function infoview.disable_widgets()
  local iv = infoview.get_current_infoview()
  if iv ~= nil then iv.info.pin:set_widget(false) end
end

function infoview.go_to(idx)
  infoview.open()
  local curr_info = infoview.get_current_infoview().info
  local curr_iv = infoview.get_current_infoview()
  local pin
  local window
  if idx then
    if idx == -1 then
      pin = curr_info.diff_pin
      window = curr_iv.diff_win
    else
      pin = curr_info.diff_pin or curr_info.pins[idx]
      window = curr_iv.pins_wins[pin.id]
    end
  else
    pin = curr_info.pin
    window = curr_iv.window
  end
  if not pin then return end

  -- if there is no last win, just go straight to the window itself
  if not pin.bufdiv:buf_last_win_valid() then
    vim.api.nvim_set_current_win(window)
  else
    pin.bufdiv:buf_enter_win()
  end
end

return infoview
