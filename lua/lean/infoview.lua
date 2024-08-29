local a = require 'plenary.async'

local Element = require('lean.tui').Element
local components = require 'lean.infoview.components'
local progress = require 'lean.progress'
local rpc = require 'lean.rpc'
local util = require 'lean._util'

local infoview = {
  -- mapping from infoview IDs to infoviews
  ---@type table<number, Infoview>
  _by_tabpage = {},
  --- Whether to print additional debug information in the infoview.
  ---@type boolean
  debug = false,
}
local options = {
  width = 50,
  height = 20,
  horizontal_position = 'bottom',
  separate_tab = false,

  autoopen = true,
  autopause = false,
  indicators = 'auto',
  show_processing = true,
  show_no_info_message = false,
  use_widgets = true,

  mappings = {
    ['K'] = 'click',
    ['<CR>'] = 'click',
    ['gd'] = 'go_to_def',
    ['gD'] = 'go_to_decl',
    ['gy'] = 'go_to_type',
    ['I'] = 'mouse_enter',
    ['i'] = 'mouse_leave',
    ['<Esc>'] = 'clear_all',
    ['C'] = 'clear_all',
    ['<LocalLeader><Tab>'] = 'goto_last_window',
  },
}

options._DEFAULTS = vim.deepcopy(options)

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
local Pin = { __extmark_ns = vim.api.nvim_create_namespace 'lean.pins' }
Pin.__index = Pin

--- An individual info.
---@class Info
---@field pin Pin
---@field pins Pin[]
---@field private __auto_diff_pin boolean
---@field private __renderer BufRenderer
---@field private __diff_renderer BufRenderer
---@field private __diff_pin Pin
---@field private __pins_element Element
---@field private __diff_pin_element Element
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
---@field private __horizontal_position "top"|"bottom"
---@field private __separate_tab? boolean
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
---@field horizontal_position? "top"|"bottom"
---@field separate_tab? boolean

--- Create a new infoview.
---@param obj InfoviewNewArgs
---@return Infoview
function Infoview:new(obj)
  obj = obj or {}
  local new_infoview = setmetatable({
    __width = obj.width or options.width,
    __height = obj.height or options.height,
    __horizontal_position = obj.horizontal_position or options.horizontal_position,
    __separate_tab = obj.separate_tab or options.separate_tab,
  }, self)
  new_infoview.info = Info:new { infoview = new_infoview }
  new_infoview.info:render()
  return new_infoview
end

function Infoview:__should_be_vertical()
  if self.__separate_tab then
    return false
  else
    local ch_aspect_ratio = 2.5 -- characters are 2.5x taller than they are wide
    return vim.o.columns > ch_aspect_ratio * vim.o.lines
  end
end

--- Open this infoview if it isn't already open
function Infoview:open()
  if self.window then
    return
  end

  local window_before_split = vim.api.nvim_get_current_win()

  if self:__should_be_vertical() then
    self.__orientation = 'vertical'
    vim.cmd('botright ' .. self.__width .. 'vsplit')
  else
    self.__orientation = 'horizontal'
    if self.__separate_tab then
      vim.cmd.tabnew()
    else
      local position = self.__horizontal_position == 'bottom' and 'botright ' or 'topleft '
      vim.cmd(position .. self.__height .. 'split')
    end
    -- FIXME: No idea why this is required (and the below immediate call to
    --        nvim_set_current_win is insufficient). Without doing things this
    --        way, when setting position to "top", either syntax highlighting
    --        breaks in the Lean window, or the cursor isn't properly placed in
    --        the Lean window (and stays in the top infoview window). For now
    --        doing this twice seems harmless for any other scenario.
    if vim.fn.has 'vim_starting' == 1 then
      vim.schedule(function()
        vim.api.nvim_set_current_win(window_before_split)
      end)
    end
  end
  vim.api.nvim_win_set_buf(0, self.info.__renderer.buf)
  -- Set the filetype now. Any earlier, and only buffer-local options will be
  -- properly set in the infoview, since the buffer isn't actually shown in a
  -- window until we run nvim_win_set_buf.
  vim.bo[self.info.__renderer.buf].filetype = 'leaninfo'
  self.window = vim.api.nvim_get_current_win()

  vim.api.nvim_set_current_win(window_before_split)

  vim.api.nvim_create_autocmd({ 'BufHidden', 'QuitPre' }, {
    group = vim.api.nvim_create_augroup('LeanInfoviewClose', { clear = false }),
    buffer = self.info.__renderer.buf,
    callback = function()
      if not self.info.__win_event_disable then
        self:__was_closed()
      end
    end,
  })

  self:focus_on_current_buffer()

  self:__refresh_diff()
  self:__update()
end

---Move this infoview's window to the right of the tab, then size it properly.
function Infoview:move_to_right()
  vim.api.nvim_win_call(self.window, function()
    vim.cmd.wincmd 'L'
  end)
  vim.api.nvim_win_set_width(self.window, options.width)
end

---Move this infoview's window to the top of the tab, then size it properly.
function Infoview:move_to_top()
  vim.api.nvim_win_call(self.window, function()
    vim.cmd.wincmd 'K'
  end)
  vim.api.nvim_win_set_height(self.window, options.height)
end

---Move this infoview's window to the bottom of the tab, then size it properly.
function Infoview:move_to_bottom()
  vim.api.nvim_win_call(self.window, function()
    vim.cmd.wincmd 'J'
  end)
  vim.api.nvim_win_set_height(self.window, options.height)
end

---Move this infoview's window (vertically or horizontally) based on the
---current screen dimensions.
function Infoview:reposition()
  if not self.window or self.__separate_tab then
    return
  end

  local orientation = unpack(vim.fn.winlayout())

  -- Resize but don't move window layouts if there are more than 2 windows.
  if #vim.api.nvim_tabpage_list_wins(0) ~= 2 then
    if orientation == 'col' then
      vim.api.nvim_win_set_height(self.window, options.height)
    else
      vim.api.nvim_win_set_width(self.window, options.width)
    end

    return
  end

  if self:__should_be_vertical() then
    if orientation == 'col' then
      self:move_to_right()
    end
  elseif orientation == 'row' then
    if self.__horizontal_position == 'bottom' then
      self:move_to_bottom()
    else
      self:move_to_top()
    end
  end
end

--- Move the cursor to the given (1-indexed) goal.
--- @param n? integer the goal number to move to, defaulting to the first
function Infoview:move_cursor_to_goal(n)
  n = n or 1
  local lines = vim.api.nvim_buf_get_lines(self.info.__renderer.buf, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:find '^⊢ ' then
      n = n - 1
      if n == 0 then
        vim.api.nvim_win_call(self.window, function()
          vim.cmd.normal { i .. 'z-2l', bang = true }
        end)
        break
      end
    end
  end
end

--- Enter the given infoview (i.e. set the current window to it).
function Infoview:enter()
  if self.window and vim.api.nvim_win_is_valid(self.window) then
    vim.api.nvim_set_current_win(self.window)
  end
end

--- API for opening an auxilliary window relative to the current infoview window.
--- @param buf number @buffer to put in the new window
--- @return number? @new window handle or nil if the infoview is closed
function Infoview:__open_win(buf)
  if not self.window then
    return
  end

  self.info.__win_event_disable = true
  local window_before_split = vim.api.nvim_get_current_win()
  self:enter()

  if self.__orientation == 'vertical' then
    vim.cmd('leftabove ' .. self.__width .. 'vsplit')
    vim.cmd('vertical resize ' .. self.__width)
  else
    if self.__separate_tab then
      vim.cmd.tabnew()
    else
      vim.cmd('leftabove ' .. self.__height .. 'split')
      vim.cmd('resize ' .. self.__height)
    end
  end
  local new_win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(new_win, buf)
  vim.bo[buf].filetype = 'leaninfo'

  vim.api.nvim_set_current_win(window_before_split)
  self.info.__win_event_disable = false

  return new_win
end

function Infoview:__refresh()
  local valid_windows = {}

  self.info.__win_event_disable = true
  for _, win in pairs { self.window, self.__diff_win } do
    if win and vim.api.nvim_win_is_valid(win) then
      table.insert(valid_windows, win)
    end
  end

  for _, win in pairs(valid_windows) do
    vim.wo[win].winfixwidth = true
  end

  for _, win in pairs(valid_windows) do
    vim.api.nvim_win_call(win, function()
      if self.__orientation == 'vertical' then
        vim.cmd('vertical resize ' .. self.__width)
      else
        if not self.__separate_tab then
          vim.cmd('resize ' .. self.__height)
        end
      end
    end)
  end
  self.info.__win_event_disable = false
end

--- Filter the pins from this infoview which are relevant to a given buffer.
--- @param buf number @the bufnr which filters the pins
--- @return Pin[]
function Infoview:pins_for(buf)
  if not self.window then
    return {}
  end

  local possible = { self.info.pin }
  vim.list_extend(possible, self.info.pins)

  local uri = vim.uri_from_bufnr(buf)
  return vim
    .iter(possible)
    :filter(function(pin)
      return pin.__position_params and pin.__position_params.textDocument.uri == uri
    end)
    :totable()
end

--FIXME: We shouldn't have both __refresh and __update
function Infoview:__update()
  local info = self.info
  if info.__win_event_disable then
    return
  end
  info:set_last_window()
  pcall(info.move_pin, info, util.make_position_params())
end

--- Either open or close a diff window for this infoview depending on whether its info has a diff pin.
function Infoview:__refresh_diff()
  if not self.window then
    return
  end

  if not self.info.__diff_pin then
    self:__close_diff()
    return
  end

  local diff_renderer = self.info.__diff_renderer

  if not self.__diff_win then
    ---@diagnostic disable-next-line: assign-type-mismatch
    self.__diff_win = self:__open_win(diff_renderer.buf)
  end

  for _, win in pairs { self.__diff_win, self.window } do
    vim.api.nvim_win_call(win, function()
      vim.cmd.diffthis()
      vim.wo.foldmethod = 'manual'
      vim.wo.wrap = true
    end)
  end

  self:__refresh()
end

--- Close this infoview's diff window.
function Infoview:__close_diff()
  if not self.window or not self.__diff_win then
    return
  end

  self.info.__win_event_disable = true
  vim.api.nvim_win_call(self.window, function()
    vim.cmd.diffoff()
  end)

  if vim.api.nvim_win_is_valid(self.__diff_win) then
    vim.api.nvim_win_call(self.__diff_win, function()
      vim.cmd.diffoff()
    end)
    vim.api.nvim_win_close(self.__diff_win, true)
  end
  self.info.__win_event_disable = false

  self.__diff_win = nil

  self:__refresh()
end

--- Close this infoview.
function Infoview:close()
  if not self.window then
    return
  end
  self:__close_diff()
  vim.api.nvim_win_close(self.window, true)
  self:__was_closed()
end

function Infoview:__was_closed()
  self.window = nil
  self.info.__renderer:event 'clear_all' -- Ensure tooltips close.
end

--- Retrieve the contents of the infoview as a table.
---@param start_line? number
---@param end_line? number
function Infoview:get_lines(start_line, end_line)
  if not self.window then
    error 'infoview is not open'
  end

  start_line = start_line or 0
  end_line = end_line or -1
  return vim.api.nvim_buf_get_lines(self.info.__renderer.buf, start_line, end_line, true)
end

--- Retrieve a specific line from the infoview window.
---@param line number
function Infoview:get_line(line)
  return self:get_lines(line, line + 1)[1]
end

--- Retrieve the contents of the diff window as a table.
---@param start_line? number
---@param end_line? number
function Infoview:get_diff_lines(start_line, end_line)
  if not self.__diff_win then
    error 'diff window is not open'
  end

  start_line = start_line or 0
  end_line = end_line or -1
  return vim.api.nvim_buf_get_lines(self.info.__diff_renderer.buf, start_line, end_line, true)
end

--- Toggle this infoview being open.
function Infoview:toggle()
  if self.window then
    self:close()
  else
    self:open()
  end
end

--- Update the info contents.
local function update_current_infoview()
  if vim.bo.filetype ~= 'lean' then
    return
  end
  local current_infoview = infoview.get_current_infoview()
  if not current_infoview then
    return
  end
  return current_infoview:__update()
end

--- Set the currently active Lean buffer to update the infoview.
function Infoview:focus_on_current_buffer()
  if self.window then
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
      group = vim.api.nvim_create_augroup('LeanInfoviewUpdate', {}),
      buffer = 0,
      callback = update_current_infoview,
    })
  end
end

---@return Info
function Info:new(opts)
  local pins_element = Element:new {
    name = 'info',
    events = {
      goto_last_window = function()
        if not self.last_window then
          return
        end
        vim.api.nvim_set_current_win(self.last_window)
      end,
    },
  }
  local new_info = setmetatable({
    pins = {},
    __infoview = opts.infoview,
    __pins_element = pins_element,
    __diff_pin_element = Element:new { name = 'diff' },
    __win_event_disable = false, -- FIXME: This too is really confusing
  }, self)
  new_info.pin = Pin:new {
    id = '1',
    paused = options.autopause,
    use_widgets = options.use_widgets,
    parent = new_info,
  }

  local count = vim.tbl_count(infoview._by_tabpage)

  local pin_bufnr = util.create_buf {
    name = 'lean://info/' .. count .. '/curr',
    options = { bufhidden = 'hide' },
    scratch = true,
  }
  new_info.__renderer = new_info.__pins_element:renderer {
    buf = pin_bufnr,
    keymaps = options.mappings,
  }
  -- Show/hide current pin extmark when entering/leaving infoview.
  local pin_augroup = vim.api.nvim_create_augroup('LeanInfoviewShowPin', { clear = false })
  vim.api.nvim_create_autocmd('WinEnter', {
    group = pin_augroup,
    buffer = pin_bufnr,
    callback = function()
      if not new_info.__win_event_disable then
        new_info:__maybe_show_pin_extmark 'current'
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinLeave', {
    group = pin_augroup,
    buffer = pin_bufnr,
    callback = function()
      if not new_info.__win_event_disable then
        new_info.pin:__hide_extmark()
      end
    end,
  })

  local diff_bufnr = util.create_buf {
    name = 'lean://info/' .. count .. '/diff',
    options = { bufhidden = 'hide' },
    listed = false,
    scratch = true,
  }
  new_info.__diff_renderer = new_info.__diff_pin_element:renderer {
    buf = diff_bufnr,
    keymaps = options.mappings,
  }

  -- Make sure we notice even if someone manually :q's the diff window.
  local close_augroup = vim.api.nvim_create_augroup('LeanInfoviewClose', { clear = false })
  vim.api.nvim_create_autocmd('BufHidden', {
    group = close_augroup,
    buffer = diff_bufnr,
    callback = function()
      if not self.__win_event_disable then
        self:__clear_diff_pin()
      end
    end,
  })

  return new_info
end

function Info:add_pin()
  local new_params = vim.deepcopy(self.pin.__ui_position_params)
  table.insert(self.pins, self.pin)
  self:__maybe_show_pin_extmark(self.pin.id)
  self.pin = Pin:new {
    id = tostring(#self.pins + 1),
    paused = options.autopause,
    use_widgets = options.use_widgets,
    parent = self,
  }
  self.pin:move(new_params)
  self:render()
end

---@param params UIParams
function Info:__set_diff_pin(params)
  if not self.__diff_pin then
    self.__diff_pin = Pin:new {
      id = 'diff',
      paused = options.autopause,
      use_widgets = options.use_widgets,
      parent = self,
    }
    self.__diff_pin_element:set_children { self.__diff_pin.__element }
    self.__diff_pin:__show_extmark(nil, 'leanDiffPinned')
  end

  self.__diff_pin:move(params)

  self:render()
end

function Info:clear_pins()
  for _, pin in pairs(self.pins) do
    pin:__teardown()
  end

  self.pins = {}
  self:render()
end

function Info:__clear_diff_pin()
  if not self.__diff_pin then
    return
  end
  self.__diff_pin:__teardown()
  self.__diff_pin = nil
  self.__diff_pin_element:set_children(nil)
  self:render()
end

--- Show a pin extmark if it is appropriate based on configuration.
function Info:__maybe_show_pin_extmark(...)
  if not options.indicators or options.indicators == 'never' then
    return
  end
  -- self.pins is apparently all *other* pins, so we check it's empty
  if options.indicators == 'auto' and #self.pins == 0 then
    return
  end
  self.pin:__show_extmark(...)
end

--- Set the current window as the last window used to update this Info.
function Info:set_last_window()
  self.last_window = vim.api.nvim_get_current_win()
end

---Update this info's pins element.
function Info:__render_pins()
  ---@param pin Pin
  ---@param current boolean
  local function render_pin(pin, current)
    local header_element = Element:new { name = 'pin-header' }
    if infoview.debug then
      header_element:add_child(Element:new { text = '-- PIN ' .. pin.id, name = 'pin-id-header' })

      local function add_attribute(text, name)
        header_element:add_child(
          Element:new { text = ' [' .. text .. ']', name = name .. '-attribute' }
        )
      end
      if current then
        add_attribute('CURRENT', 'current')
      end
      if pin.paused then
        add_attribute('PAUSED', 'paused')
      end
      if pin.loading then
        add_attribute('LOADING', 'loading')
      end
    end

    local params = pin.__ui_position_params
    if not current and params then
      local bufnr = vim.fn.bufnr(params.filename)
      local filename
      if bufnr ~= -1 then
        filename = vim.api.nvim_buf_get_name(bufnr)
      else
        filename = params.filename
      end
      if not infoview.debug then
        header_element:add_child(Element:new { text = '-- ', name = 'pin-id-header' })
      else
        header_element:add_child(Element:new { text = ': ', name = 'pin-header-separator' })
      end
      local location_text = ('%s at %d:%d'):format(filename, params.row + 1, params.col + 1)
      header_element:add_child(Element:new { text = location_text, name = 'pin-location' })

      header_element.highlightable = true
      header_element.events = {
        click = function()
          if self.last_window then
            vim.api.nvim_set_current_win(self.last_window)
            local uri_bufnr = vim.fn.bufnr(params.filename)
            vim.api.nvim_set_current_buf(uri_bufnr)
            vim.api.nvim_win_set_cursor(0, { params.row + 1, params.col })
          end
        end,
      }
    end
    if not header_element:is_empty() then
      header_element:add_child(Element:new { text = '\n', name = 'pin-header-end' })
    end

    local pin_element = Element:new { name = 'pin_wrapper', children = { header_element } }
    if pin.__element then
      pin_element:add_child(pin.__element)
    end

    return pin_element
  end

  self.__pins_element:set_children { render_pin(self.pin, true) }
  for _, pin in ipairs(self.pins) do
    self.__pins_element:add_child(Element:new { text = '\n\n', name = 'pin_spacing' })
    self.__pins_element:add_child(render_pin(pin, false))
  end
end

--- Update this info's physical contents.
function Info:render()
  self:__render_pins()

  self.__renderer:render()
  if self.__diff_pin then
    self.__diff_renderer:render()
  end

  -- Set the cursor to the line with first goal (just after the marker).
  if vim.api.nvim_get_current_win() ~= self.__infoview.window then
    self.__infoview:move_cursor_to_goal()
  end

  self.__infoview:__refresh_diff()
  collectgarbage() -- FIXME: Why??
end

--- Update the diff pin to use the current pin's positon params if they are valid,
--- and the provided params if they are not.
---@param params? UIParams
function Info:__update_auto_diff_pin(params)
  if
    self.pin.__ui_position_params and util.position_params_valid(self.pin.__ui_position_params)
  then
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
  if self.__auto_diff_pin then
    self:__update_auto_diff_pin(params)
  end
  self.pin:move(params)
end

--- Toggle auto diff pin mode.
--- @param clear boolean @clear the pin when disabling auto diff pin mode?
function Info:__toggle_auto_diff_pin(clear)
  if self.__auto_diff_pin then
    self.__auto_diff_pin = false
    if clear then
      self:__clear_diff_pin()
    end
  else
    self.__auto_diff_pin = true
    -- only update the diff pin if there isn't already one
    if not self.__diff_pin then
      self:__update_auto_diff_pin()
    end
  end
end

---@return Pin
function Pin:new(obj)
  obj = obj or {}

  local paused = obj.paused or false
  local use_widgets = obj.use_widgets
  if use_widgets == nil then
    use_widgets = true
  end
  obj.paused = nil
  obj.use_widgets = nil

  return setmetatable(
    vim.tbl_extend('keep', obj, {
      paused = paused,
      __data_element = Element:new { name = 'pin-data' },
      __element = Element:new { name = 'pin' },
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
  if not params then
    return
  end
  local buf = vim.fn.bufnr(params.filename)
  if buf == -1 then
    return
  end
  local line = params.row
  local col = params.col

  self:__update_extmark_style(buf, line, col)

  self:update_position()
end

function Pin:__update_extmark_style(buf, line, col)
  -- not a brand new extmark
  if not buf then
    if not self.__extmark then
      return
    end
    buf = self.__extmark_buf
    local extmark_pos =
      vim.api.nvim_buf_get_extmark_by_id(buf, self.__extmark_ns, self.__extmark, {})
    if vim.tbl_isempty(extmark_pos) then
      return
    end
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
      end_col = vim.str_byteindex(buf_line, next_utf16, true)
    else
      end_col = col
    end
  end

  self.__extmark = vim.api.nvim_buf_set_extmark(buf, self.__extmark_ns, line, col, {
    id = self.__extmark,
    end_col = end_col,
    hl_group = self.__extmark_hl_group,
    virt_text = self.__extmark_virt_text,
    virt_text_pos = 'right_align',
  })
  self.__extmark_buf = buf
end

--- Update pin position based on extmark, used directly when changing text, indirectly when setting position.
function Pin:update_position()
  local extmark = self.__extmark
  if not extmark then
    return
  end

  local buf = self.__extmark_buf
  if buf == -1 then
    return
  end

  local extmark_pos = vim.api.nvim_buf_get_extmark_by_id(buf, self.__extmark_ns, extmark, {})

  local encoding = util._get_offset_encoding(buf) or 'utf-32'
  local use_utf16 = encoding == 'utf-16'
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
  local new_ui_params = {
    filename = vim.uri_to_fname(vim.uri_from_bufnr(buf)),
    row = extmark_pos[1],
    col = extmark_pos[2],
  }
  self.__position_params = new_params
  self.__ui_position_params = new_ui_params
end

function Pin:__show_extmark(name, hlgroup)
  self.__extmark_hl_group = hlgroup or 'leanPinned'
  if name then
    self.__extmark_virt_text = { { '← ' .. (name or self.id), 'Comment' } }
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
  if self.paused then
    return
  end
  self.paused = true

  -- abort any pending requests
  self.__ticker:lock()
end

---Restart updating this pin.
function Pin:unpause()
  if not self.paused then
    return
  end
  self.paused = false
  self:update()
end

---Toggle whether this pin receives updates.
function Pin:toggle_pause()
  if not self.paused then
    self:pause()
  else
    self:unpause()
  end
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
  if self.loading then
    return false
  end
  self.loading = true
  self.__element:set_children { self.__data_element }
  return true
end

function Pin:async_update()
  -- FIXME: For one, we're guarding here against the infoview being updated
  --        while it's closed, which if we continued, would end up calling
  --        render. That doesn't seem right, somewhere that should happen
  --        higher up than here.
  if self.paused or not self.__info.__infoview.window then
    return
  end

  local tick = self.__ticker:lock()

  if self.__position_params and not self.paused then
    self:__update(tick)
  end
  if not tick:check() then
    return
  end

  if self.loading then
    self.loading = false
    self.__element:set_children { self.__data_element }
    self:__render_parents()
  end
end

Pin.update = a.void(Pin.async_update)

---@param opts table?
---@param tick Tick
---@return Element?
function Pin:__mk_data_elem(tick, opts)
  local params = self.__position_params

  local buf = vim.uri_to_bufnr(params.textDocument.uri)
  if buf == -1 then
    error 'No corresponding buffer found for update.'
  end

  if progress.is_processing_at(params) then
    return options.show_processing and components.PROCESSING or nil
  end

  if not tick:check() then
    return
  end

  local sess = rpc.open(buf, params)
  local blocks = vim
    .iter({
      components.goal_at(buf, params, sess, self.__use_widgets) or {},
      components.term_goal_at(buf, params, sess, self.__use_widgets) or {},
      components.diagnostics_at(buf, params, sess, self.__use_widgets) or {},
      components.user_widgets_at(buf, params, sess, self.__use_widgets) or {},
    })
    :flatten()
    :totable()

  if options.show_no_info_message and vim.tbl_isempty(blocks) then
    return components.NO_INFO
  end

  return Element:concat(blocks, '\n\n', opts)
end

--- async function to update this pin's contents given the current position.
function Pin:__update(tick)
  if self:__started_loading() then
    self:__render_parents()
  end

  local new_data_element
  local opts = {
    events = {
      clear_all = function(ctx) ---@param ctx ElementEventContext
        ---@diagnostic disable-next-line: need-check-nil
        new_data_element:find(function(element) ---@param element Element
          if element.events.clear then
            element.events.clear(ctx)
          end
        end)
        pcall(vim.api.nvim_set_current_win, ctx.self.last_win)
      end,
    },
  }
  new_data_element = self:__mk_data_elem(tick, opts)
  if new_data_element then
    self.__data_element = new_data_element
  end
end

--- Close all open infoviews (across all tabs).
function infoview.close_all()
  for _, each in pairs(infoview._by_tabpage) do
    each:close()
  end
end

--- Update pins corresponding to the given URI.
---@param uri string
function infoview.__update_pin_by_uri(uri)
  if not infoview.enabled then
    return
  end
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

--- on_lines callback to update pins position according to the given textDocument/didChange parameters.
function infoview.__update_pin_positions(_, bufnr, _, _, _, _, _, _, _)
  local pins = vim.iter(infoview._by_tabpage):map(function(each)
    return each:pins_for(bufnr)
  end)
  for pin in pins:flatten(1) do
    -- immediately mark the pin as loading (useful for tests)
    if pin:__started_loading() then
      vim.schedule(function()
        pin:__render_parents()
      end)
    end
    vim.schedule(function()
      pin:update_position()
      pin:update()
    end)
  end
end

-- FIXME: We never seem to call nvim_buf_detach, nor use this for anything.
--        This seems related to #346 (as a potential further fix improvement)
--        as part of what was happening there is that we still are attached
--        to buffers whose infoviews are already closed, and likely should
--        be detaching from them so we don't pointlessly call into
--        __update_pin_positions
local attached_buffers = {}

--- Callback when entering a Lean buffer.
local function infoview_bufenter()
  -- Open an infoview for the current buffer if it isn't already open.
  local tabpage = vim.api.nvim_get_current_tabpage()
  if not infoview._by_tabpage[tabpage] and options.autoopen() then
    local new_infoview = Infoview:new {}
    infoview._by_tabpage[tabpage] = new_infoview
    new_infoview:open()
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if not attached_buffers[bufnr] then
    vim.api.nvim_buf_attach(bufnr, false, { on_lines = infoview.__update_pin_positions })
    attached_buffers[bufnr] = true
  end
  update_current_infoview()
end

--- Enable and open the infoview across all Lean buffers.
function infoview.enable(opts)
  options = vim.tbl_extend('force', options, opts)
  infoview.mappings = options.mappings
  infoview.enabled = true
  infoview.set_autoopen(options.autoopen)

  vim.api.nvim_create_autocmd('Filetype', {
    group = vim.api.nvim_create_augroup('LeanInfoviewInit', {}),
    pattern = { 'lean' },
    callback = function(event)
      local bufnr = event.buf
      if bufnr == vim.api.nvim_get_current_buf() then
        -- because FileType can happen after BufEnter
        infoview_bufenter()
        local current_infoview = infoview.get_current_infoview()
        if not current_infoview then
          return
        end
        current_infoview:focus_on_current_buffer()
      end

      local focus_augroup = vim.api.nvim_create_augroup('LeanInfoviewSetFocus', { clear = false })
      vim.api.nvim_create_autocmd('BufEnter', {
        group = focus_augroup,
        buffer = bufnr,
        callback = infoview_bufenter,
      })

      -- WinEnter is necessary for the edge case where you have
      -- a file open in a tab with an infoview and move to a
      -- new window in a new tab with that same file but no infoview
      vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
        group = focus_augroup,
        buffer = bufnr,
        callback = function()
          local current_infoview = infoview.get_current_infoview()
          if not current_infoview then
            return
          end
          current_infoview:focus_on_current_buffer()
        end,
      })
    end,
  })
end

--- Set whether a new infoview is automatically opened when entering Lean buffers.
function infoview.set_autoopen(autoopen)
  if autoopen == true then
    autoopen = function()
      return true
    end
  elseif autoopen == false then
    autoopen = function()
      return false
    end
  end
  options.autoopen = autoopen
end

--- Set whether a new pin is automatically paused.
function infoview.set_autopause(autopause)
  options.autopause = autopause
end

--- Get the infoview corresponding to the current window.
---@return Infoview
function infoview.get_current_infoview()
  return infoview._by_tabpage[vim.api.nvim_get_current_tabpage()]
end

--- Open the current infoview (or ensure it is already open).
function infoview.open()
  local tabpage = vim.api.nvim_get_current_tabpage()
  local current_infoview = infoview.get_current_infoview()
  if not current_infoview then
    current_infoview = Infoview:new {}
    infoview._by_tabpage[tabpage] = current_infoview
  end
  current_infoview:open()
  return current_infoview
end

--- Close the current infoview (or ensure it is already closed).
function infoview.close()
  local current_infoview = infoview.get_current_infoview()
  if current_infoview then
    current_infoview:close()
  end
end

--- Toggle whether the current infoview is opened or closed.
function infoview.toggle()
  local iv = infoview.get_current_infoview()
  if iv ~= nil then
    iv:toggle()
  else
    infoview.open()
  end
end

--- Toggle whether the current pin receives updates.
function infoview.pin_toggle_pause()
  local iv = infoview.get_current_infoview()
  if iv then
    iv.info.pin:toggle_pause()
  end
end

--- Add a pin to the current cursor location.
function infoview.add_pin()
  if vim.bo.filetype ~= 'lean' then
    return
  end
  local current_infoview = infoview.open()
  current_infoview.info:set_last_window()
  current_infoview.info:add_pin()
end

--- Set the location for a diff pin to the current cursor location.
function infoview.set_diff_pin()
  if vim.bo.filetype ~= 'lean' then
    return
  end
  local current_infoview = infoview.open()
  current_infoview.info:set_last_window()
  current_infoview.info:__set_diff_pin(util.make_position_params())
end

--- Clear any pins in the current infoview.
function infoview.clear_pins()
  local iv = infoview.get_current_infoview()
  if iv then
    iv.info:clear_pins()
  end
end

--- Clear a diff pin in the current infoview.
function infoview.clear_diff_pin()
  local iv = infoview.get_current_infoview()
  if iv then
    iv.info:__clear_diff_pin()
  end
end

--- Toggle whether "auto-diff" mode is active for the current infoview.
function infoview.toggle_auto_diff_pin(clear)
  if vim.bo.filetype ~= 'lean' then
    return
  end
  local current_infoview = infoview.open()
  current_infoview.info:__toggle_auto_diff_pin(clear)
end

--- Enable widgets in the current infoview.
function infoview.enable_widgets()
  local iv = infoview.get_current_infoview()
  if iv ~= nil then
    iv.info.pin:enable_widgets()
  end
end

--- Disable widgets in the current infoview.
function infoview.disable_widgets()
  local iv = infoview.get_current_infoview()
  if iv ~= nil then
    iv.info.pin:disable_widgets()
  end
end

--- Move the cursor to the infoview window.
function infoview.go_to()
  local curr_info = infoview.open().info
  -- if there is no last win, just go straight to the window itself
  if not curr_info.__renderer:last_win_valid() then
    infoview.get_current_infoview():enter()
  else
    curr_info.__renderer:enter_win()
  end
end

--- Move the current infoview to the appropriate spot based on the
--- current screen dimensions.
--- Does nothing if there are more than 2 open windows.
function infoview.reposition()
  local iv = infoview.get_current_infoview()
  if iv then
    iv:reposition()
  end
end

return infoview
