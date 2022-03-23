local protocol = require('vim.lsp.protocol')

local a = require('plenary.async')

local Element = require('lean.widgets').Element
local components = require('lean.infoview.components')
local lean3 = require('lean.lean3')
local leanlsp = require('lean.lsp')
local is_lean_buffer = require('lean').is_lean_buffer
local util = require('lean._util')
local set_augroup = util.set_augroup
local rpc = require('lean.rpc')

local infoview = {
  -- mapping from infoview IDs to infoviews
  ---@type table<number, Infoview>
  _by_tabpage = {},
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
    show_no_info_message = false,
    use_widgets = true,

    mappings = {
      ['K'] = 'click',
      ['<CR>'] = 'click',
      ['I'] = 'mouse_enter',
      ['i'] = 'mouse_leave',
      ['<Esc>'] = 'clear_all',
      ['C'] = 'clear_all',
      ['<LocalLeader><Tab>'] = 'goto_last_window',
    }
  }
}

--- An individual pin.
---@class Pin
---@field id string @a label to identify the pin
---@field private __data_element Element
---@field private __element Element
---@field private __extmark number
---@field private __extmark_buf number
---@field private __extmark_hl_group string
---@field private __extmark_virt_text table
---@field private __ticker Ticker
---@field private __info Info
---@field private __ui_position_params UIParams
---@field private __use_widgets boolean
local Pin = { __extmark_ns = vim.api.nvim_create_namespace("lean.pins") }
Pin.__index = Pin

--- An individual info.
---@class Info
---@field pin Pin
---@field pins Pin[]
---@field private __auto_diff_pin Pin
---@field private __renderer BufRenderer
---@field private __diff_renderer BufRenderer
---@field private __diff_pin Pin
---@field private __pins_element Element
---@field private __infoview Infoview @the infoview this info is attached to
---@field private __win_event_disable boolean
local Info = {}
Info.__index = Info

--- A "view" on an info (i.e. window).
---@class Infoview
---@field info Info
---@field window integer
---@field private __orientation "vertical"|"horizontal"
---@field private __width number
---@field private __height number
---@field private __diff_win integer
local Infoview = {}
Infoview.__index = Infoview

--- Enables printing of extra debugging information in the infoview.
function infoview.enable_debug()
  infoview.debug = true
end

---@class InfoviewNewArgs
---@field width? integer
---@field height? integer

--- Create a new infoview.
---@param obj InfoviewNewArgs
---@return Infoview
function Infoview:new(obj)
  obj = obj or {}
  local new_infoview = setmetatable({
    __width = obj.width or options.width,
    __height = obj.height or options.height
  }, self)
  new_infoview.info = Info:new{ infoview = new_infoview }
  return new_infoview
end

--- Open this infoview if it isn't already open
function Infoview:open()
  if self.window then return end

  local window_before_split = vim.api.nvim_get_current_win()

  local win_width = vim.api.nvim_win_get_width(window_before_split)
  local win_height = vim.api.nvim_win_get_height(window_before_split)

  local ch_aspect_ratio = 2.5 -- characters are 2.5x taller than they are wide
  if win_width > ch_aspect_ratio * win_height then
    self.__orientation = 'vertical'
    vim.cmd('botright ' .. self.__width .. 'vsplit')
  else
    self.__orientation = 'horizontal'
    vim.cmd('botright ' .. self.__height .. 'split')
  end
  vim.api.nvim_win_set_buf(0, self.info.__renderer.buf)
  -- Set the filetype now. Any earlier, and only buffer-local options will be
  -- properly set in the infoview, since the buffer isn't actually shown in a
  -- window until we run nvim_win_set_buf.
  vim.api.nvim_buf_set_option(self.info.__renderer.buf, 'filetype', 'leaninfo')
  self.window = vim.api.nvim_get_current_win()

  vim.api.nvim_set_current_win(window_before_split)

  -- Make sure we notice even if someone manually :q's the infoview window.
  set_augroup("LeanInfoviewClose", string.format([[
    autocmd BufHidden <buffer=%d> lua require'lean.infoview'.__was_closed(%d)
  ]], self.info.__renderer.buf, self.window), self.info.__renderer.buf)

  self:focus_on_current_buffer()

  self:__refresh_diff()
end

--- API for opening an auxilliary window relative to the current infoview window.
--- @param buf number @buffer to put in the new window
--- @return number @new window handle or nil if the infoview is closed
function Infoview:__open_win(buf)
  if not self.window then return end

  self.info.__win_event_disable = true
  local window_before_split = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(self.window)

  if self.__orientation == 'vertical' then
    vim.cmd('leftabove ' .. self.__width .. 'vsplit')
    vim.cmd('vertical resize ' .. self.__width)
  else
    vim.cmd('leftabove ' .. self.__height .. 'split')
    vim.cmd('resize ' .. self.__height)
  end
  local new_win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(new_win, buf)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'leaninfo')

  vim.api.nvim_set_current_win(window_before_split)
  self.info.__win_event_disable = false

  return new_win
end

function Infoview:__refresh()
  local valid_windows = {}

  self.info.__win_event_disable = true
  for _, win in pairs({self.window, self.__diff_win}) do
    if win and vim.api.nvim_win_is_valid(win) then
      table.insert(valid_windows, win)
    end
  end

  for _, win in pairs(valid_windows) do
    vim.api.nvim_win_call(win, function()
      vim.api.nvim_command('set winfixwidth')
    end)
  end

  for _, win in pairs(valid_windows) do
    vim.api.nvim_win_call(win, function()
      if self.__orientation == "vertical" then
        vim.cmd('vertical resize ' .. self.__width)
      else
        vim.cmd('resize ' .. self.__height)
      end
    end)
  end
  self.info.__win_event_disable = false
end

--- Either open or close a diff window for this infoview depending on whether its info has a diff pin.
function Infoview:__refresh_diff()
  if not self.window then return end

  if not self.info.__diff_pin then self:__close_diff() return end

  local diff_renderer = self.info.__diff_renderer

  if not self.__diff_win then
    self.__diff_win = self:__open_win(diff_renderer.buf)
  end

  for _, win in pairs({self.__diff_win, self.window}) do
    vim.api.nvim_win_call(win, function()
      vim.api.nvim_command"diffthis"
      vim.api.nvim_command("set foldmethod=manual")
      vim.api.nvim_command("setlocal wrap")
    end)
  end

  self:__refresh()
end

--- Close this infoview's diff window.
function Infoview:__close_diff()
  if not self.window or not self.__diff_win then return end

  self.info.__win_event_disable = true
  vim.api.nvim_win_call(self.window, function() vim.api.nvim_command"diffoff" end)

  if vim.api.nvim_win_is_valid(self.__diff_win) then
    vim.api.nvim_win_call(self.__diff_win, function() vim.api.nvim_command"diffoff" end)
    vim.api.nvim_win_close(self.__diff_win, true)
  end
  self.info.__win_event_disable = false

  self.__diff_win = nil

  self:__refresh()
end

--- Close this infoview.
function Infoview:close()
  if not self.window then return end
  self:__close_diff()
  vim.api.nvim_win_close(self.window, true)
  self:__was_closed()
end

function Infoview:__was_closed()
  self.window = nil
  self.info:__was_closed()
end

--- Retrieve the contents of the infoview as a table.
function Infoview:get_lines(start_line, end_line)
  if not self.window then error("infoview is not open") end
  start_line = start_line or 0
  end_line = end_line or -1
  return vim.api.nvim_buf_get_lines(self.info.__renderer.buf, start_line, end_line, true)
end

--- Toggle this infoview being open.
function Infoview:toggle()
  if self.window then self:close() else self:open() end
end

--- Set the currently active Lean buffer to update the infoview.
function Infoview:focus_on_current_buffer()
  if self.window then
    set_augroup("LeanInfoviewUpdate", [[
      autocmd CursorMoved <buffer> lua require'lean.infoview'.__update()
      autocmd CursorMovedI <buffer> lua require'lean.infoview'.__update()
    ]], 0)
  else
    set_augroup("LeanInfoviewUpdate", "", 0)
  end
end

---@return Info
function Info:new(opts)
  local pins_element = Element:new{
    name = "info",
    events = {
      goto_last_window = function()
        if not self.last_window then return end
        vim.api.nvim_set_current_win(self.last_window)
      end
    }
  }
  local new_info = setmetatable({
    pins = {},
    __infoview = opts.infoview,
    __pins_element = pins_element,
    __win_event_disable = false,
  }, self)
  new_info.pin = Pin:new{
    id = '1',
    paused = options.autopause,
    use_widgets = options.use_widgets,
    parent = new_info
  }

  local count = vim.tbl_count(infoview._by_tabpage)

  local pin_bufnr = util.create_buf{
    name = 'lean://info/' .. count .. '/curr',
    options = { bufhidden = 'hide' },
    scratch = true,
  }
  new_info.__renderer = new_info.__pins_element:renderer{
    buf = pin_bufnr,
    keymaps = options.mappings,
  }
  -- Show/hide current pin extmark when entering/leaving infoview.
  set_augroup("LeanInfoviewShowPin", string.format([[
    autocmd WinEnter <buffer=%d> lua require'lean.infoview'.__show_curr_pin()
    autocmd WinLeave <buffer=%d> lua require'lean.infoview'.__hide_curr_pin()
  ]], pin_bufnr, pin_bufnr), pin_bufnr)

  local diff_bufnr = util.create_buf{
    name = 'lean://info/' .. count .. '/diff',
    options = { bufhidden = 'hide' },
    listed = false,
    scratch = true,
  }
  new_info.__diff_renderer = new_info.pin.__element:renderer{
    buf = diff_bufnr,
    keymaps = options.mappings,
  }
  -- Make sure we notice even if someone manually :q's the diff window.
  set_augroup("LeanInfoviewClose", string.format([[
    autocmd BufHidden <buffer=%d> lua require'lean.infoview'.__diff_was_closed()
  ]], diff_bufnr), diff_bufnr)

  new_info:render()

  return new_info
end

function Info:add_pin()
  local new_params = vim.deepcopy(self.pin.__ui_position_params)
  table.insert(self.pins, self.pin)
  self:__maybe_show_pin_extmark(self.pin.id)
  self.pin = Pin:new{
    id = tostring(#self.pins + 1),
    paused = options.autopause,
    use_widgets = options.use_widgets,
    parent = self
  }
  self.pin:move(new_params)
  self:render()
end

---@param params UIParams
function Info:__set_diff_pin(params)
  if not self.__diff_pin then
    self.__diff_pin = Pin:new{
      id = 'diff',
      paused = options.autopause,
      use_widgets = options.use_widgets,
      parent = self
    }
    self.__diff_renderer.__element = self.__diff_pin.__element
    self.__diff_pin:__show_extmark(nil, 'leanDiffPinned')
  end

  self.__diff_pin:move(params)

  self:render()
end

-- Ensure tooltips close.
function Info:__was_closed()
  self.__renderer:event('clear_all')
end

function Info:clear_pins()
  for _, pin in pairs(self.pins) do
    pin:__teardown()
  end

  self.pins = {}
  self:render()
end

function Info:__clear_diff_pin()
  if not self.__diff_pin then return end
  self.__diff_pin:__teardown()
  self.__diff_pin = nil
  self.__diff_renderer.__element = self.pin.__element
  self:render()
end

--- Show a pin extmark if it is appropriate based on configuration.
function Info:__maybe_show_pin_extmark(...)
  if not options.indicators or options.indicators == "never" then return end
  -- self.pins is apparently all *other* pins, so we check it's empty
  if options.indicators == "auto" and #self.pins == 0 then return end
  self.pin:__show_extmark(...)
end

--- Set the current window as the last window used to update this Info.
function Info:set_last_window()
  self.last_window = vim.api.nvim_get_current_win()
end

--- Update this info's pins element.
function Info:__render_pins()
  local function render_pin(pin, current)
    local header_element = Element:new{ name = "pin-header" }
    if infoview.debug then
      header_element:add_child(
        Element:new{ text = "-- PIN " .. pin.id, name = "pin-id-header" }
      )

      local function add_attribute(text, name)
        header_element:add_child(
          Element:new{ text = " [" .. text .. "]", name = name .. "-attribute" }
        )
      end
      if current then add_attribute("CURRENT", "current") end
      if pin.paused then add_attribute("PAUSED", "paused") end
      if pin.loading then add_attribute("LOADING", "loading") end
    end

    local params = pin.__ui_position_params
    if not current and params then
      local bufnr = vim.fn.bufnr(params.filename)
      local filename
      if bufnr ~= -1 then
        filename = vim.fn.bufname(bufnr)
      else
        filename = params.filename
      end
      if not infoview.debug then
        header_element:add_child(Element:new{ text = "-- ", name = "pin-id-header" })
      else
        header_element:add_child(Element:new{ text = ": ", name = "pin-header-separator" })
      end
      local location_text = ("%s at %d:%d"):format(filename,
        params.row + 1, params.col + 1)
      header_element:add_child(Element:new{ text = location_text, name = "pin-location" })

      header_element.highlightable = true
      header_element.events = {
        click = function()
          if self.last_window then
            vim.api.nvim_set_current_win(self.last_window)
            local uri_bufnr = vim.fn.bufnr(params.filename)
            vim.api.nvim_set_current_buf(uri_bufnr)
            vim.api.nvim_win_set_cursor(0, { params.row + 1, params.col })
          end
        end
      }
    end
    if not header_element:is_empty() then
      header_element:add_child(Element:new{ text = "\n", name = "pin-header-end" })
    end

    local pin_element = Element:new{ name = "pin_wrapper", children = { header_element } }
    if pin.__element then pin_element:add_child(pin.__element) end

    return pin_element
  end

  self.__pins_element:set_children{ render_pin(self.pin, true) }
  for _, pin in ipairs(self.pins) do
    self.__pins_element:add_child(Element:new{ text = "\n\n", name = "pin_spacing" })
    self.__pins_element:add_child(render_pin(pin, false))
  end
end

--- Update this info's physical contents.
function Info:render()
  self:__render_pins()

  self.__renderer:render()
  if self.__diff_pin then self.__diff_renderer:render() end

  self.__infoview:__refresh_diff()
  collectgarbage()
end

--- Update the diff pin to use the current pin's positon params if they are valid,
--- and the provided params if they are not.
---@param params UIParams
function Info:__update_auto_diff_pin(params)
  if self.pin.__ui_position_params and util.position_params_valid(self.pin.__ui_position_params) then
    -- update diff pin to previous position
    self:__set_diff_pin(self.pin.__ui_position_params)
  elseif params then
    -- if previous position invalid, use current position
    self:__set_diff_pin(params)
  end
end

--- Move the current pin to the specified location.
---@param params UIParams
function Info:move_pin(params)
  if self.__auto_diff_pin then self:__update_auto_diff_pin(params) end
  self.pin:move(params)
end

--- Toggle auto diff pin mode.
--- @param clear boolean @clear the pin when disabling auto diff pin mode?
function Info:__toggle_auto_diff_pin(clear)
  if self.__auto_diff_pin then
    self.__auto_diff_pin = false
    if clear then self:__clear_diff_pin() end
  else
    self.__auto_diff_pin = true
    -- only update the diff pin if there isn't already one
    if not self.__diff_pin then self:__update_auto_diff_pin() end
  end
end

---@return Pin
function Pin:new(obj)
  obj = obj or {}

  local paused = obj.paused or false
  local use_widgets = obj.use_widgets or true
  obj.paused = nil
  obj.use_widgets = nil

  return setmetatable(
    vim.tbl_extend("keep", obj, {
      paused = paused,
      __data_element = Element:new{ name = "pin-data" },
      __element = Element:new{ name = "pin" },
      __info = obj.parent,
      __ticker = util.Ticker:new(),
      __use_widgets = use_widgets,
    }),
    self
  )
end

--- Enable widgets for this pin.
function Pin:enable_widgets()
  self.__use_widgets = true
  self:update()
end

--- Disable widgets (in favor of plaintext goals) for this pin.
function Pin:disable_widgets()
  self.__use_widgets = false
  self:update()
end

function Pin:__teardown()
  self.__info = nil
  if self.__extmark then
    vim.api.nvim_buf_del_extmark(self.__extmark_buf, self.__extmark_ns, self.__extmark)
  end
end

--- Update pin extmark based on position, used when resetting pin position.
---@param params UIParams
function Pin:__update_extmark(params)
  if not params then return end
  local buf = vim.fn.bufnr(params.filename)
  if buf == -1 then return end
  local line = params.row
  local col = params.col

  self:__update_extmark_style(buf, line, col)

  self:update_position()
end

function Pin:__update_extmark_style(buf, line, col)
  -- not a brand new extmark
  if not buf then
    if not self.__extmark then return end
    buf = self.__extmark_buf
    local extmark_pos = vim.api.nvim_buf_get_extmark_by_id(buf, self.__extmark_ns, self.__extmark, {})
    if vim.tbl_isempty(extmark_pos) then return end
    line = extmark_pos[1]
    col = extmark_pos[2]
  end

  local buf_line = vim.api.nvim_buf_get_lines(buf, line, line + 1, false)[1]
  local end_col = 0
  if buf_line then
    if col < #buf_line then
      -- vim.str_utfindex rounds up to the next UTF16 index if in the middle of a UTF8 sequence;
      -- so convert next byte to UTF16 and back to get UTF8 index of next codepoint
      local _, next_utf16 = vim.str_utfindex(buf_line, col + 1)
      end_col = (col < #buf_line) and vim.str_byteindex(buf_line, next_utf16, true)
    else
      end_col = col
    end
  end

  self.__extmark = vim.api.nvim_buf_set_extmark(buf, self.__extmark_ns,
    line, col,
    {
      id = self.__extmark;
      end_col = end_col;
      hl_group = self.__extmark_hl_group;
      virt_text = self.__extmark_virt_text;
      virt_text_pos = "right_align";
    })
  self.__extmark_buf = buf
end

--- Update pin position based on extmark, used directly when changing text, indirectly when setting position.
function Pin:update_position()
  local extmark = self.__extmark
  if not extmark then return end

  local buf = self.__extmark_buf
  if buf == -1 then return end

  local extmark_pos = vim.api.nvim_buf_get_extmark_by_id(buf, self.__extmark_ns, extmark, {})

  local encoding = util._get_offset_encoding(buf) or "utf-32"
  local use_utf16 = encoding == "utf-16"
  local new_pos = {}

  new_pos.line = extmark_pos[1]
  local buf_line = vim.api.nvim_buf_get_lines(buf, new_pos.line, new_pos.line + 1, false)[1]
  if buf_line then
    local utf32, utf16 = vim.str_utfindex(buf_line, extmark_pos[2])
    new_pos.character = use_utf16 and utf16 or utf32
  else
    new_pos.character = 0
  end

  local new_params = { textDocument = { uri = vim.uri_from_bufnr(buf) }, position = new_pos }
  local new_ui_params = { filename = vim.uri_to_fname(vim.uri_from_bufnr(buf)),
    row = extmark_pos[1], col = extmark_pos[2] }
  self.__position_params = new_params
  self.__ui_position_params = new_ui_params
end

function Pin:__show_extmark(name, hlgroup)
  self.__extmark_hl_group = hlgroup or 'leanPinned'
  if name then
    self.__extmark_virt_text = {{"← " .. (name or self.id), "Comment"}}
  else
    self.__extmark_virt_text = nil
  end
  self:__update_extmark_style()
end

function Pin:__hide_extmark()
  self.__extmark_hl_group = nil
  self.__extmark_virt_text = nil
  self:__update_extmark_style()
end

---Stop updating this pin.
function Pin:pause()
  if self.paused then return end
  self.paused = true


  -- abort any pending requests
  self.__ticker:lock()
end

---Restart updating this pin.
function Pin:unpause()
  if not self.paused then return end
  self.paused = false
  self:update()
end

---Toggle whether this pin receives updates.
function Pin:toggle_pause()
  if not self.paused then self:pause() else self:unpause() end
end

--- Triggered when manually moving a pin.
---@param params UIParams
function Pin:move(params)
  self:__update_extmark(params)
  self:update()
end

function Pin:__render_parents()
  self.__info:render()
end

---Indicate that the pin has started loading.
function Pin:__started_loading()
  if self.loading then return false end
  self.loading = true
  self.__element:set_children{ self.__data_element }
  self:__render_parents()
  return true
end

function Pin:async_update(force)
  if not force and self.paused then return end

  local tick = self.__ticker:lock()

  if self.__position_params and (force or not self.paused) then
    self:__update(tick)
  end
  if not tick:check() then return end

  if self.loading then
    self.loading = false
    self.__element:set_children{ self.__data_element }
    self:__render_parents()
  end
end

Pin.update = a.void(Pin.async_update)

---@param tick Tick
---@return Element?
function Pin:__mk_data_elem(tick)
  local params = self.__position_params
  local line = params.position.line

  ::retry::

  local buf = vim.fn.bufnr(vim.uri_to_fname(params.textDocument.uri))
  if buf == -1 then
    error("No corresponding buffer found for update.")
  end

  if require"lean.progress".is_processing_at(params) then
    if options.show_processing then
      return Element:new{
        text = "Processing file...",
        name = "processing-msg"
      }
    end
    return Element:new()
  end

  if vim.api.nvim_buf_get_option(buf, "ft") == "lean3" then
    return lean3.render_pin(self, buf, params, self.__use_widgets, options.lean3)
  end

  local sess = rpc.open(buf, params)
  if not tick:check() then return end

  local goal_element
  if self.__use_widgets then
    local goal, err = sess:getInteractiveGoals(params)
    if not tick:check() then return end
    if err and err.code == protocol.ErrorCodes.ContentModified then
      goto retry
    end
    if not err then
      goal_element = components.interactive_goals(goal, sess)
    end
  end

  if not goal_element then
    local err, goal = leanlsp.plain_goal(params, buf)
    if not tick:check() then return end
    if err and err.code == protocol.ErrorCodes.ContentModified then
      goto retry
    end
    goal_element = components.goal(goal)
  end

  local term_goal_element
  if self.__use_widgets then
    local term_goal, err = sess:getInteractiveTermGoal(params)
    if not tick:check() then return end
    if err and err.code == protocol.ErrorCodes.ContentModified then
      goto retry
    end
    if not err then
      term_goal_element = components.interactive_term_goal(term_goal, sess)
    end
  end

  if not term_goal_element then
    local err, term_goal = leanlsp.plain_term_goal(params, buf)
    if not tick:check() then return end
    if err and err.code == protocol.ErrorCodes.ContentModified then
      goto retry
    end
    term_goal_element = components.term_goal(term_goal)
  end

  local blocks = {}
  vim.list_extend(blocks, goal_element)
  vim.list_extend(blocks, term_goal_element)
  if options.show_no_info_message and #goal_element + #term_goal_element == 0 then
    table.insert(blocks, Element:new{ text = "No info.", name = "no-tactic-term" })
  end

  local diagnostics_element
  if self.__use_widgets then
    local diags, err = sess:getInteractiveDiagnostics({ start = line, ['end'] = line + 1 })
    if not tick:check() then return end
    if err and err.code == protocol.ErrorCodes.ContentModified then
      goto retry
    end
    if not err then
      diagnostics_element = components.interactive_diagnostics(diags, line, sess)
    end
  end

  vim.list_extend(blocks, diagnostics_element or components.diagnostics(buf, line))

  return Element:concat(blocks, '\n\n')
end

--- async function to update this pin's contents given the current position.
function Pin:__update(tick)
  self:__started_loading()

  local new_data_element = self:__mk_data_elem(tick)
  if not new_data_element or not tick:check() then return end

  new_data_element.events.clear_all = function(ctx) ---@param ctx ElementEventContext
    local last_window = ctx.self.last_win
    new_data_element:find(function (element) ---@param element Element
      if element.events.clear then element.events.clear(ctx) end
    end)
    pcall(vim.api.nvim_set_current_win, last_window)
  end

  self.__data_element = new_data_element
end

--- Close all open infoviews (across all tabs).
function infoview.close_all()
  for _, each in pairs(infoview._by_tabpage) do
    each:close()
  end
end

--- An infoview was closed, either directly via `Infoview.close` or manually.
--- Will be triggered via a `WinClosed` autocmd.
function infoview.__was_closed(window)
  -- FIXME: Why is infoview._by_tabpage[tabpage] here the wrong infoview!?
  --        Try using it and it will fail the `closes independently via quit`
  --        test.
  -- local tabpage, _ = unpack(vim.fn.win_id2tabwin(window))
  for _, each in pairs(infoview._by_tabpage) do
    if each.window == window then
      if each.info.__win_event_disable then return end
      each:__was_closed()
    end
  end
end

--- An infoview diff window was closed.
--- Will be triggered via a `WinClosed` autocmd.
function infoview.__diff_was_closed()
  local current_infoview = infoview.get_current_infoview()
  local info = current_infoview.info
  if info.__win_event_disable then return end
  info:__clear_diff_pin()
end

--- An infoview was entered, show the extmark for the current pin.
--- Will be triggered via a `WinEnter` autocmd.
function infoview.__show_curr_pin()
  local current_infoview = infoview.get_current_infoview()
  if not current_infoview then return end
  local info = current_infoview.info
  if info.__win_event_disable then return end
  current_infoview.info:__maybe_show_pin_extmark("current")
end

--- An infoview was left, hide the extmark for the current pin.
--- Will be triggered via a `WinLeave` autocmd.
function infoview.__hide_curr_pin()
  local current_infoview = infoview.get_current_infoview()
  if not current_infoview then return end
  local info = current_infoview.info
  if info.__win_event_disable then return end
  info.pin:__hide_extmark()
end

--- Update the info contents appropriately for Lean 4 or 3.
function infoview.__update()
  if not is_lean_buffer() then return end
  local current_infoview = infoview.get_current_infoview()
  if not current_infoview then return end
  local info = current_infoview.info
  if info.__win_event_disable then return end
  info:set_last_window()
  pcall(info.move_pin, info, util.make_position_params())
end

--- Update pins corresponding to the given URI.
function infoview.__update_pin_by_uri(uri)
  if infoview.enabled then
  for _, each in pairs(infoview._by_tabpage) do
    local pins = { each.info.pin }
    vim.list_extend(pins, each.info.pins)
    for _, pin in ipairs(pins) do
      if pin.__position_params and pin.__position_params.textDocument.uri == uri then
        pin:update()
      end
    end
  end
  end
end

--- on_lines callback to update pins position according to the given textDocument/didChange parameters.
function infoview.__update_pin_positions(_, bufnr, _, _, _, _, _, _, _)
  for _, each in pairs(infoview._by_tabpage) do
    local pins = { each.info.pin }
    vim.list_extend(pins, each.info.pins)
    for _, pin in ipairs(pins) do
      if pin.__position_params and pin.__position_params.textDocument.uri == vim.uri_from_bufnr(bufnr) then
        vim.schedule_wrap(function()
          pin:update_position()
          pin:update(false)
        end)()
      end
    end
  end
end

--- Enable and open the infoview across all Lean buffers.
function infoview.enable(opts)
  options = vim.tbl_extend("force", options._DEFAULTS, opts)
  infoview.mappings = options.mappings
  infoview.enabled = true
  infoview.set_autoopen(options.autoopen)
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
    local current_infoview = infoview.get_current_infoview()
    if not current_infoview then return end
    current_infoview:focus_on_current_buffer()
  end

  -- WinEnter is necessary for the edge case where you have
  -- a file open in a tab with an infoview and move to a
  -- new window in a new tab with that same file but no infoview
  set_augroup("LeanInfoviewSetFocus", string.format([[
    autocmd BufEnter <buffer=%d> lua require'lean.infoview'.__bufenter()
    autocmd BufEnter,WinEnter <buffer=%d> lua if require'lean.infoview'.get_current_infoview()]] ..
    [[ then require'lean.infoview'.get_current_infoview():focus_on_current_buffer() end
  ]], bufnr, bufnr), 0)
end

--- Set whether a new infoview is automatically opened when entering Lean buffers.
function infoview.set_autoopen(autoopen)
  if autoopen == true then
    autoopen = function() return true end
  elseif autoopen == false then
    autoopen = function() return false end
  end
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

--- Get the infoview corresponding to the current window.
---@return Infoview
function infoview.get_current_infoview()
  return infoview._by_tabpage[vim.api.nvim_get_current_tabpage()]
end

--- Open an infoview for the current buffer if it isn't already open.
function infoview.__maybe_autoopen()
  local tabpage = vim.api.nvim_get_current_tabpage()
  if infoview._by_tabpage[tabpage] or not options.autoopen() then return end
  local new_infoview = Infoview:new{}
  infoview._by_tabpage[tabpage] = new_infoview
  new_infoview:open()
end

function infoview.open()
  local tabpage = vim.api.nvim_get_current_tabpage()
  local current_infoview = infoview.get_current_infoview()
  if not current_infoview then
    current_infoview = Infoview:new{}
    infoview._by_tabpage[tabpage] = current_infoview
  end
  current_infoview:open()
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
  infoview.get_current_infoview().info:__set_diff_pin(util.make_position_params())
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
    iv.info:__clear_diff_pin()
  end
end

function infoview.toggle_auto_diff_pin(clear)
  if not is_lean_buffer() then return end
  infoview.open()
  infoview.get_current_infoview().info:__toggle_auto_diff_pin(clear)
end

function infoview.enable_widgets()
  local iv = infoview.get_current_infoview()
  if iv ~= nil then iv.info.pin:enable_widgets() end
end

function infoview.disable_widgets()
  local iv = infoview.get_current_infoview()
  if iv ~= nil then iv.info.pin:disable_widgets() end
end

function infoview.go_to()
  infoview.open()
  local curr_info = infoview.get_current_infoview().info
  -- if there is no last win, just go straight to the window itself
  if not curr_info.__renderer:last_win_valid() then
    vim.api.nvim_set_current_win(infoview.get_current_infoview().window)
  else
    curr_info.__renderer:enter_win()
  end
end

return infoview
