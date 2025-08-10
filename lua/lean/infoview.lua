---@mod lean.infoview The Infoview

---@brief [[
--- Infoview-specific interaction for customizing or controlling the display of
--- Lean's interactive goal state.
---@brief ]]

local Buffer = require 'std.nvim.buffer'
local Window = require 'std.nvim.window'
local a = require 'plenary.async'
local text_document_position_to_string = require('std.lsp').text_document_position_to_string

local Element = require('lean.tui').Element
local Locations = require 'lean.infoview.locations'
local components = require 'lean.infoview.components'
local interactive_goal = require 'lean.widget.interactive_goal'
local log = require 'lean.log'
local progress = require 'lean.progress'
local rpc = require 'lean.rpc'
local util = require 'lean._util'

local infoview = {
  -- mapping from infoview IDs to infoviews
  ---@type table<number, Infoview>
  _by_tabpage = {},

  ---Whether to print additional debug information in the infoview.
  ---@type boolean
  debug = false,
}
---@type lean.infoview.Config
local options = {
  width = 50,
  height = 20,
  orientation = 'auto',
  horizontal_position = 'bottom',
  separate_tab = false,

  autoopen = true,
  autopause = false,
  indicators = 'auto',
  show_processing = true,
  show_no_info_message = false,
  show_term_goals = true,
  use_widgets = true,

  mappings = {
    ['K'] = 'click',
    ['<CR>'] = 'click',
    ['gK'] = 'select',
    ['gd'] = 'go_to_def',
    ['gD'] = 'go_to_decl',
    ['gy'] = 'go_to_type',
    ['<Esc>'] = 'clear_all',
    ['C'] = 'clear_all',
    ['<LocalLeader><Tab>'] = 'goto_last_window',
  },
}

options._DEFAULTS = vim.deepcopy(options)

--TODO: Move use_widgets here, if not delete it.
---@class InfoviewViewOptions
---@field show_types boolean show type hypotheses
---@field show_instances boolean show instance hypotheses
---@field show_hidden_assumptions boolean show hypothesis names which are inaccessible
---@field show_let_values boolean show let-value bodies
---@field show_term_goals boolean show expected types?
---@field reverse boolean order hypotheses bottom-to-top

---An individual pin.
---@class Pin
---@field id string a label to identify the pin
---@field private __data_element Element
---@field private __element Element
---@field private __extmark number
---@field private __extmark_buffer Buffer
---@field private __extmark_hl_group string
---@field private __extmark_virt_text table
---@field private __tick integer
---@field private __info Info
---@field private __ui_position_params UIParams
---@field private __use_widgets boolean
local Pin = { __extmark_ns = vim.api.nvim_create_namespace 'lean.pins' }
Pin.__index = Pin

---An individual info.
---@class Info
---@field pin Pin
---@field pins Pin[]
---@field private __auto_diff_pin boolean
---@field private __renderer BufRenderer
---@field private __diff_renderer BufRenderer
---@field private __diff_pin Pin
---@field private __pins_element Element
---@field private __diff_pin_element Element
---@field private __infoview Infoview the infoview this info is attached to
---@field private __win_event_disable boolean
local Info = {}
Info.__index = Info

---A "view" on an info (i.e. window).
---@class Infoview
---@field info Info
---@field window Window
---@field private __orientation "vertical"|"horizontal"
---@field private __orientation_pref "auto"|"vertical"|"horizontal"
---@field private __width number
---@field private __height number
---@field private __horizontal_position "top"|"bottom"
---@field private __separate_tab? boolean
---@field private __diff_win? Window
local Infoview = {}
Infoview.__index = Infoview

---@class InfoviewNewArgs
---@field width? integer
---@field height? integer
---@field orientation? "auto"|"vertical"|"horizontal"
---@field horizontal_position? "top"|"bottom"
---@field separate_tab? boolean

---Create a new infoview.
---@param obj InfoviewNewArgs
---@return Infoview
function Infoview:new(obj)
  obj = obj or {}
  local new_infoview = setmetatable({
    __orientation_pref = obj.orientation or options.orientation,
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
  if self.__separate_tab or self.__orientation_pref == 'horizontal' then
    return false
  else
    local ch_aspect_ratio = 2.5 -- characters are 2.5x taller than they are wide
    return vim.o.columns > ch_aspect_ratio * vim.o.lines or self.__orientation_pref == 'vertical'
  end
end

---Open this infoview if it isn't already open
function Infoview:open()
  if self.window then
    return
  end

  local window_before_split = Window:current()

  if self:__should_be_vertical() then
    self.__orientation = 'vertical'
    vim.cmd('botright ' .. self.__width .. 'vsplit')
  else
    self.__orientation = 'horizontal'
    if self.__separate_tab then
      vim.cmd.tabnew()
    elseif self.__horizontal_position == 'bottom' then
      vim.cmd('botright ' .. self.__height .. 'split')
    else
      vim.cmd('topleft ' .. self.__height .. 'split')

      -- FIXME: If vim is first starting and we're creating a new topmost
      --        window neovim seems to want to put the cursor in it. This seems
      --        to be the case even if we set enter=false, and even though
      --        below below we call `:make_current` immediately.
      --        It seems pretty likely there's some Neovim bug here which needs
      --        minimizing.
      if vim.fn.has 'vim_starting' == 1 then
        vim.schedule(function()
          window_before_split:make_current()
        end)
      end
    end
  end

  self.window = Window:current()
  self.window:set_buffer(self.info.__renderer.buffer)
  -- Set the filetype now. Any earlier, and only buffer-local options will be
  -- properly set in the infoview, since the buffer isn't actually shown in a
  -- window until we `set_buffer`.
  self.info.__renderer.buffer.o.filetype = 'leaninfo'

  window_before_split:make_current()

  self.info.__renderer.buffer:create_autocmd({ 'BufHidden', 'QuitPre' }, {
    group = vim.api.nvim_create_augroup('LeanInfoviewClose', { clear = false }),
    callback = function()
      self:__was_closed()
    end,
  })

  self:focus_on_current_buffer()

  self:__refresh_diff()
  self:__update()
end

---Move this infoview's window to the right of the tab, then size it properly.
function Infoview:move_to_right()
  self.window:call(function()
    vim.cmd.wincmd 'L'
  end)
  self.window:set_width(options.width)
end

---Move this infoview's window to the top of the tab, then size it properly.
function Infoview:move_to_top()
  self.window:call(function()
    vim.cmd.wincmd 'K'
  end)
  self.window:set_height(options.height)
end

---Move this infoview's window to the bottom of the tab, then size it properly.
function Infoview:move_to_bottom()
  self.window:call(function()
    vim.cmd.wincmd 'J'
  end)
  self.window:set_height(options.height)
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
      self.window:set_height(options.height)
    else
      self.window:set_width(options.width)
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

---Move the cursor to the given (1-indexed) goal.
---@param n? integer the goal number to move to, defaulting to the first
function Infoview:move_cursor_to_goal(n)
  if not self.window then
    log:error { message = 'Moving cursor in closed infoview.' }
    return
  end

  n = n or 1
  for i, line in ipairs(self.info.__renderer.buffer:lines()) do
    if line:find '^⊢ ' then
      n = n - 1
      if n == 0 then
        self.window:call(function()
          vim.cmd.normal { i .. 'z-2l', bang = true }
        end)
        break
      end
    end
  end
end

---Enter the given infoview (i.e. set the current window to it).
function Infoview:enter()
  if self.window and self.window:is_valid() then
    self.window:make_current()
  end
end

---@class FilterSelection
---@field description string
---@field option string

---Interactively set view options for this infoview.
function Infoview:select_view_options()
  ---@type FilterSelection[]
  local choices = {
    {
      name = 'show instances',
      description = 'Show hypotheses which are instances of Lean type classes?',
      option = 'show_instances',
    },
    {
      name = 'show types',
      description = 'Show hypotheses which are types (rather than terms)?',
      option = 'show_types',
    },
    {
      name = 'show inaccessible names',
      description = 'Show inaccessible names (those ending in ✝)?',
      option = 'show_hidden_assumptions',
    },
    {
      name = 'show let bodies',
      description = 'Show the bodies of let-values?',
      option = 'show_let_values',
    },
    {
      name = 'show term goals',
      description = 'Show "expected type" goals?',
      option = 'show_term_goals',
    },
    {
      name = 'reverse order',
      description = 'Show hypotheses from bottom-to-top rather than top-to-bottom?',
      option = 'reverse',
    },
  }

  local previous = require 'lean.config'().infoview.view_options or {}
  require('lean.tui').select_many(choices, {
    format_item = function(item)
      return item.name
    end,
    tooltip_for = function(item)
      return item.description
    end,
    start_selected = function(choice)
      return previous[choice.option]
    end,
    title = 'View Options',
    relative_window = self.window,
  }, function(selected, unselected)
    -- XXX: This needs fixing when there are multiple infoviews.
    local view_options = {}
    for each in vim.iter(selected) do
      view_options[each.option] = true
    end
    for each in vim.iter(unselected) do
      view_options[each.option] = false
    end

    local config = vim.g.lean_config
    config.infoview.view_options = view_options
    vim.g.lean_config = config
  end)
end

---Wait until the infoview has finished processing.
---@param timeout_ms? number the maximum time to wait, defaulting to 10s
function Infoview:wait(timeout_ms)
  timeout_ms = timeout_ms or 10000
  local info = self.info
  local pins = vim.list_extend({ info.pin, info.__diff_pin }, info.pins)
  local succeeded, _ = vim.wait(timeout_ms, function()
    pins = vim
      .iter(pins)
      :filter(function(pin)
        local processing = progress.at(pin.__position_params)
        return pin.loading or processing == progress.Kind.processing
      end)
      :totable()
    return #pins == 0
  end)

  if succeeded then
    return
  end
  error(('Pins %s are still processing.'):format(vim.inspect(pins)))
end

---API for opening an auxilliary window relative to the current infoview window.
---@param buffer Buffer buffer to put in the new window
---@return Window? window a new window handle, or nil if the infoview is closed
function Infoview:__open_win(buffer)
  if not self.window then
    return
  end

  self.info.__win_event_disable = true
  local window_before_split = Window:current()
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
  local new_win = Window:current()
  new_win:set_buffer(buffer)
  buffer.o.filetype = 'leaninfo'

  window_before_split:make_current()
  self.info.__win_event_disable = false

  return new_win
end

function Infoview:__refresh()
  log:debug { message = 'refreshing infoview', window = self.window.id }

  local valid_windows = {}

  for _, win in pairs { self.window, self.__diff_win } do
    if win and win:is_valid() then
      table.insert(valid_windows, win)
    end
  end

  for _, win in pairs(valid_windows) do
    win.o.winfixwidth = true
  end

  for _, win in pairs(valid_windows) do
    win:call(function()
      if self.__orientation == 'vertical' then
        vim.cmd('vertical resize ' .. self.__width)
      else
        if not self.__separate_tab then
          vim.cmd('resize ' .. self.__height)
        end
      end
    end)
  end
end

---Filter the pins from this infoview which are relevant to a given buffer.
---@param uri string the URI which filters the pins
---@return Pin[]
function Infoview:pins_for(uri)
  if not self.window then
    return {}
  end

  local possible = { self.info.pin }
  vim.list_extend(possible, self.info.pins)

  return vim
    .iter(possible)
    :filter(function(pin)
      return pin.__position_params and pin.__position_params.textDocument.uri == uri
    end)
    :totable()
end

--FIXME: We shouldn't have both __refresh and __update
function Infoview:__update()
  log:debug { message = 'updating infoview', window = self.window and self.window.id or nil }

  local info = self.info
  if info.__win_event_disable then
    return
  end
  info:update_last_window()
  info:move_pin(util.make_position_params())
end

---Directly mark that the infoview has died. What a shame.
function Infoview:died()
  self.info.pin.__data_element = components.LSP_HAS_DIED
  local params = self.info.pin.__ui_position_params
  progress.proc_infos[params.textDocument.uri] = {
    {
      kind = progress.Kind.fatal_error,
      range = { start = params.position, ['end'] = params.position },
    },
  }
  self.info.pin:update()
end

---Either open or close a diff window for this infoview depending on whether its info has a diff pin.
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
    self.__diff_win = self:__open_win(diff_renderer.buffer)
  end

  for _, win in pairs { self.__diff_win, self.window } do
    win:call(function()
      vim.cmd.diffthis()
      vim.wo.foldmethod = 'manual'
      vim.wo.wrap = true
    end)
  end

  self:__refresh()
end

---Close this infoview's diff window.
function Infoview:__close_diff()
  if not self.window or not self.__diff_win then
    return
  end

  self.window:call(function()
    vim.cmd.diffoff()
  end)

  if self.__diff_win:is_valid() then
    self.__diff_win:call(function()
      vim.cmd.diffoff()
    end)
    self.__diff_win:force_close()
  end

  self.__diff_win = nil

  self:__refresh()
end

---Close this infoview.
function Infoview:close()
  if not self.window then
    return
  end
  self:__close_diff()
  self.window:force_close()
  self:__was_closed()
end

function Infoview:__was_closed()
  self.window = nil
  self.info.__renderer:event 'clear_all' -- Ensure tooltips close.
end

---Retrieve the contents of the infoview as a table.
---@param start_line? number
---@param end_line? number
function Infoview:get_lines(start_line, end_line)
  if not self.window then
    error 'infoview is not open'
  end
  return self.info.__renderer.buffer:lines(start_line, end_line)
end

---Retrieve a specific line from the infoview window.
---@param line number
---@return string? line the infoview contents at the given line
function Infoview:get_line(line)
  if not self.window then
    error 'infoview is not open'
  end
  return self.info.__renderer.buffer:line(line, false)
end

---Retrieve the contents of the diff window as a table.
---@param start_line? number
---@param end_line? number
function Infoview:get_diff_lines(start_line, end_line)
  if not self.__diff_win then
    error 'diff window is not open'
  end
  return self.info.__diff_renderer.buffer:lines(start_line, end_line)
end

---Toggle this infoview being open.
function Infoview:toggle()
  if self.window then
    self:close()
  else
    self:open()
  end
end

---Update the info contents.
local function update_current_infoview()
  if
    vim.bo.filetype ~= 'lean' or vim.api.nvim_win_get_config(0).relative ~= '' -- floating window
  then
    return
  end
  local current_infoview = infoview.get_current_infoview()
  if not current_infoview then
    return
  end
  return current_infoview:__update()
end

---Set the currently active Lean buffer to update the infoview.
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
  local new_info = setmetatable({
    pins = {},
    __infoview = opts.infoview,
    __pins_element = Element:new { name = 'info' },
    __diff_pin_element = Element:new { name = 'diff' },
    __win_event_disable = false, -- FIXME: This too is really confusing
  }, self)

  new_info.__pins_element.events = {
    goto_last_window = function()
      new_info:jump_to_last_window()
    end,
  }

  new_info.pin = Pin:new {
    id = '1',
    paused = options.autopause,
    use_widgets = options.use_widgets,
    parent = new_info,
  }

  local id = vim.api.nvim_get_current_tabpage()

  local pin_buffer = Buffer.create {
    name = 'lean://info/' .. id .. '/curr',
    options = { bufhidden = 'hide' },
    scratch = true,
  }
  new_info.__renderer = new_info.__pins_element:renderer {
    buffer = pin_buffer,
    keymaps = options.mappings,
  }
  -- Show/hide current pin extmark when entering/leaving infoview.
  local pin_augroup = vim.api.nvim_create_augroup('LeanInfoviewShowPin', { clear = false })
  pin_buffer:create_autocmd('WinEnter', {
    group = pin_augroup,
    callback = function()
      new_info:__maybe_show_pin_extmark 'current'
    end,
  })
  pin_buffer:create_autocmd('WinLeave', {
    group = pin_augroup,
    callback = function()
      new_info.pin:__hide_extmark()
    end,
  })

  local diff_buffer = Buffer.create {
    name = 'lean://info/' .. id .. '/diff',
    options = { bufhidden = 'hide' },
    listed = false,
    scratch = true,
  }
  new_info.__diff_renderer = new_info.__diff_pin_element:renderer {
    buffer = diff_buffer,
    keymaps = options.mappings,
  }

  -- Make sure we notice even if someone manually :q's the diff window.
  diff_buffer:create_autocmd('BufHidden', {
    group = vim.api.nvim_create_augroup('LeanInfoviewClose', { clear = false }),
    callback = function()
      self:__clear_diff_pin()
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

---Show a pin extmark if it is appropriate based on configuration.
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

---Set the current window as the last window used to update this Info.
function Info:update_last_window()
  self.last_window = Window:current()
end

---Jump to the last window used to update this Info, if any.
function Info:jump_to_last_window()
  if not self.last_window then
    return
  end
  self.last_window:make_current()
end

---Update this info's physical contents.
function Info:render()
  local function click_header(params)
    return function()
      local start_window = Window:current()
      self:jump_to_last_window()

      if start_window:is_current() then
        return
      end

      local buffer = Buffer:from_uri(params.textDocument.uri)
      buffer:make_current()
      Window:current():set_cursor { params.position.line + 1, params.position.character }
    end
  end

  self.__pins_element:set_children { self.pin.__element }
  for _, pin in ipairs(self.pins) do
    self.__pins_element:add_child(Element:new { text = '\n\n', name = 'pin_spacing' })
    self.__pins_element:add_child(pin:render_with_header(click_header))
  end

  self.__renderer:render()
  if self.__diff_pin then
    self.__diff_renderer:render()
  end

  -- Set the cursor to the line with first goal (just after the marker).
  if self.__infoview.window and not self.__infoview.window:is_current() then
    self.__infoview:move_cursor_to_goal()
  end

  self.__infoview:__refresh_diff()
  collectgarbage() -- FIXME: Why??
end

---Update the diff pin to use the current pin's positon params if they are valid,
---and the provided params if they are not.
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

---Move the current pin to the specified location.
---@param params UIParams
function Info:move_pin(params)
  if self.__auto_diff_pin then
    self:__update_auto_diff_pin(params)
  end
  self.pin:move(params)
end

---Toggle auto diff pin mode.
---@param clear boolean clear the pin when disabling auto diff pin mode?
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
      __data_element = Element.EMPTY,
      __element = Element:new { name = 'pin' },
      __info = obj.parent,
      __tick = 0,
      __use_widgets = use_widgets,
    }),
    self
  )
end

---Return all selectable elements within this pin.
---@return Iter
function Pin:selectable()
  return self.__data_element:filter(function(element)
    return element.events.select ~= nil
  end)
end

---Enable widgets for this pin.
function Pin:enable_widgets()
  self.__use_widgets = true
  self:update()
end

---Disable widgets (in favor of plaintext goals) for this pin.
function Pin:disable_widgets()
  self.__use_widgets = false
  self:update()
end

---Render a pin with an extra header indicating its location.
---
---@param click_header fun(params:UIParams):fun():nil
function Pin:render_with_header(click_header)
  local params = self.__ui_position_params
  local header_element = Element:new {
    name = 'pin-header',
    text = ('-- %s\n'):format(text_document_position_to_string(params)),
    highlightable = true,
    events = { click = click_header(params) },
  }
  return Element:new { children = { header_element, self.__element } }
end

function Pin:__teardown()
  self.__info = nil
  if self.__extmark then
    self.__extmark_buffer:del_extmark(self.__extmark_ns, self.__extmark)
  end
end

---Update pin extmark based on position, used when resetting pin position.
---@param params UIParams
function Pin:__update_extmark(params)
  if not params then
    return
  end
  local buffer = Buffer:from_uri(params.textDocument.uri)
  if not buffer:is_loaded() then
    return
  end

  self:__update_extmark_style(buffer, params.position.line, params.position.character)

  self:update_position()
end

---@param buffer? Buffer
---@param line? number
---@param col? number
function Pin:__update_extmark_style(buffer, line, col)
  -- not a brand new extmark
  if not buffer then
    if not self.__extmark then
      return
    end
    buffer = self.__extmark_buffer
    local extmark_pos =
      vim.api.nvim_buf_get_extmark_by_id(buffer.bufnr, self.__extmark_ns, self.__extmark, {})
    if vim.tbl_isempty(extmark_pos) then
      return
    end
    line = extmark_pos[1]
    col = extmark_pos[2]
  end

  local buf_line = buffer:line(line, false)
  local end_col = 0
  if buf_line then
    if col < #buf_line then
      -- vim.str_utfindex rounds up to the next UTF16 index if in the middle of a UTF8 sequence;
      -- so convert next byte to UTF16 and back to get UTF8 index of next codepoint
      local succeeded, _, next_utf16 = pcall(vim.str_utfindex, buf_line, col + 1)
      if succeeded then
        end_col = vim.str_byteindex(buf_line, next_utf16, true)
      else
        log:error { message = 'str_utfindex failed', buf_line = buf_line, col = col }
        end_col = col
      end
    else
      end_col = col
    end
  end

  self.__extmark = buffer:set_extmark(self.__extmark_ns, line, col, {
    id = self.__extmark,
    end_col = end_col,
    hl_group = self.__extmark_hl_group,
    virt_text = self.__extmark_virt_text,
    virt_text_pos = 'right_align',
  })
  self.__extmark_buffer = buffer
end

---Update pin position based on extmark, used directly when changing text, indirectly when setting position.
function Pin:update_position()
  local extmark = self.__extmark
  if not extmark then
    return
  end

  local buffer = self.__extmark_buffer
  if not buffer:is_loaded() then
    return
  end

  local extmark_pos =
    vim.api.nvim_buf_get_extmark_by_id(buffer.bufnr, self.__extmark_ns, extmark, {})

  local new_pos = { line = extmark_pos[1] }

  local buf_line = buffer:line(new_pos.line, false)
  if buf_line then
    local succeeded, _, utf16 = pcall(vim.str_utfindex, buf_line, extmark_pos[2])
    if succeeded then
      new_pos.character = utf16
    else
      log:error { message = 'str_utfindex failed', buf_line = buf_line, extmark_pos = extmark_pos }
      new_pos.character = 0
    end
  else
    new_pos.character = 0
  end

  local uri = buffer:uri()
  ---@type lsp.TextDocumentPositionParams
  self.__position_params = { textDocument = { uri = uri }, position = new_pos }
  self.__ui_position_params = {
    textDocument = { uri = uri },
    position = { line = extmark_pos[1], character = extmark_pos[2] },
  }
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
  self.paused = true
end

---Restart updating this pin.
function Pin:unpause()
  if self.paused then
    self.paused = false
    self:update()
  end
end

---Toggle whether this pin receives updates.
function Pin:toggle_pause()
  if self.paused then
    self:unpause()
  else
    self:pause()
  end
end

---@param params UIParams
function Pin:move(params)
  self:__update_extmark(params)
  self:update()
end

---Render the combined contents of the infoview for the given parameters.
---
---@param params lsp.TextDocumentPositionParams
---@param use_widgets boolean
---@return Element
local function contents_for(params, use_widgets)
  local processing = progress.at(params)
  if processing == progress.Kind.processing then
    return options.show_processing and components.PROCESSING or Element.EMPTY
  end

  local blocks
  if processing == progress.Kind.fatal_error then
    log:debug {
      message = 'progress.Kind.fatal_error diagnostics',
      params = params,
    }
    blocks = interactive_goal.diagnostics(params)
  else
    local view_options = require 'lean.config'().infoview.view_options
    local sess = rpc.open(params)

    blocks = vim
      .iter({
        components.goal_at(params, sess, use_widgets) or {},
        view_options.show_term_goals and components.term_goal_at(params, sess, use_widgets) or {},
        components.user_widgets_at(params, sess, use_widgets) or {},
        components.diagnostics_at(params, sess, use_widgets) or {},
      })
      :flatten(1)
      :totable()
  end

  if vim.tbl_isempty(blocks) then
    local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
    if vim.tbl_isempty(vim.lsp.get_clients { bufnr = bufnr, name = 'leanls' }) then
      return components.LSP_HAS_DIED
    elseif options.show_no_info_message then
      return components.NO_INFO
    else
      return components.EMPTY
    end
  end

  local new_data_element
  new_data_element = Element:concat(blocks, '\n\n', {
    ---@type EventCallbacks
    events = {
      clear_all = function(ctx) ---@param ctx ElementEventContext
        new_data_element:find(function(element) ---@param element Element
          ---@type fun(ctx):boolean?
          local clear = element.events['clear']
          if clear then
            clear(ctx)
          end
        end)
        Locations.clear(params)
        ctx.jump_to_last_window()
      end,
    },
  }) or Element.EMPTY
  return new_data_element
end

Pin.update = a.void(function(self)
  -- FIXME: For one, we're guarding here against the infoview being updated
  --        while it's closed, which if we continued, would end up calling
  --        render. That doesn't seem right, somewhere that should happen
  --        higher up than here.
  if self.paused or not self.__info.__infoview.window then
    return
  end

  local params = self.__position_params
  if not params then
    return
  end

  if not Buffer:from_uri(params.textDocument.uri):is_loaded() then
    return
  end

  -- FIXME: This tick business is some bizarre way of telling whether
  --        info:render calls back into us to re-render this pin.
  self.__tick = self.__tick + 1
  local tick = self.__tick

  if not self.loading then
    self.loading = true
    self.__info:render()
  end
  self.__data_element = contents_for(self.__position_params, self.__use_widgets)

  if self.__tick == tick and self.__info and self.loading then
    self.loading = false
    self.__element:set_children { self.__data_element }
    self.__info:render()
  end
end)

---Close all open infoviews (across all tabs).
function infoview.close_all()
  for _, each in pairs(infoview._by_tabpage) do
    each:close()
  end
end

---Update pins corresponding to the given URI.
---@param uri string
function infoview.__update_pin_by_uri(uri)
  for _, each in pairs(infoview._by_tabpage) do
    for _, pin in pairs(each:pins_for(uri)) do
      log:debug {
        message = 'updating pin',
        uri = uri,
        window = pin.__info.__infoview.window.id,
      }
      pin:update()
    end
  end
end

---on_lines callback to update pins position according to the given textDocument/didChange parameters.
function infoview.__update_pin_positions(_, bufnr, tick, _, _, _, _, _, _)
  log:debug { message = 'updating pin positions', bufnr = bufnr, tick = tick }
  local uri = vim.uri_from_bufnr(bufnr)
  for _, each in pairs(infoview._by_tabpage) do
    for _, pin in pairs(each:pins_for(uri)) do
      pin.loading = true
      pin:update_position()
      vim.schedule(function()
        pin:update()
      end)
    end
  end
end

-- FIXME: We never seem to call nvim_buf_detach, nor use this for anything.
--        This seems related to #346 (as a potential further fix improvement)
--        as part of what was happening there is that we still are attached
--        to buffers whose infoviews are already closed, and likely should
--        be detaching from them so we don't pointlessly call into
--        __update_pin_positions
local attached_buffers = {}

---Callback when entering a Lean buffer.
local function infoview_bufenter()
  -- Open an infoview for the current buffer if it isn't already open.
  local tabpage = vim.api.nvim_get_current_tabpage()
  if not infoview._by_tabpage[tabpage] and options.autoopen() then
    log:debug { message = 'opening infoview', tabpage = tabpage }
    local new_infoview = Infoview:new {}
    infoview._by_tabpage[tabpage] = new_infoview
    new_infoview:open()
  end

  local buffer = Buffer:current()
  if not attached_buffers[buffer.bufnr] then
    buffer:attach { on_lines = infoview.__update_pin_positions }
    attached_buffers[buffer.bufnr] = true
  end
  update_current_infoview()
end

---Enable and open the infoview across all Lean buffers.
---@param opts lean.infoview.Config
function infoview.enable(opts)
  ---@type lean.infoview.MergedConfig
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

      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('LeanInfoviewLSPDied', { clear = false }),
        buffer = bufnr,
        callback = function()
          local current_infoview = infoview.get_current_infoview()
          if not current_infoview then
            return
          end
          current_infoview:died()
        end,
      })

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

---Set whether a new infoview is automatically opened when entering Lean buffers.
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

---Set whether a new pin is automatically paused.
function infoview.set_autopause(autopause)
  options.autopause = autopause
end

---Get the infoview corresponding to the current window.
---@return Infoview
function infoview.get_current_infoview()
  return infoview._by_tabpage[vim.api.nvim_get_current_tabpage()]
end

---Open the current infoview (or ensure it is already open).
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

---Close the current infoview (or ensure it is already closed).
function infoview.close()
  local current_infoview = infoview.get_current_infoview()
  if current_infoview then
    current_infoview:close()
  end
end

---Toggle whether the current infoview is opened or closed.
function infoview.toggle()
  local iv = infoview.get_current_infoview()
  if iv ~= nil then
    iv:toggle()
  else
    infoview.open()
  end
end

---Toggle whether the current pin receives updates.
function infoview.pin_toggle_pause()
  local iv = infoview.get_current_infoview()
  if iv then
    iv.info.pin:toggle_pause()
  end
end

---Add a pin to the current cursor location.
function infoview.add_pin()
  if vim.bo.filetype ~= 'lean' then
    return
  end
  local current_infoview = infoview.open()
  current_infoview.info:update_last_window()
  current_infoview.info:add_pin()
end

---Set the location for a diff pin to the current cursor location.
function infoview.set_diff_pin()
  if vim.bo.filetype ~= 'lean' then
    return
  end
  local current_infoview = infoview.open()
  current_infoview.info:update_last_window()
  current_infoview.info:__set_diff_pin(util.make_position_params())
end

---Clear any pins in the current infoview.
function infoview.clear_pins()
  local iv = infoview.get_current_infoview()
  if iv then
    iv.info:clear_pins()
  end
end

---Clear a diff pin in the current infoview.
function infoview.clear_diff_pin()
  local iv = infoview.get_current_infoview()
  if iv then
    iv.info:__clear_diff_pin()
  end
end

---Toggle whether "auto-diff" mode is active for the current infoview.
function infoview.toggle_auto_diff_pin(clear)
  if vim.bo.filetype ~= 'lean' then
    return
  end
  local current_infoview = infoview.open()
  current_infoview.info:__toggle_auto_diff_pin(clear)
end

---Enable widgets in the current infoview.
function infoview.enable_widgets()
  local iv = infoview.get_current_infoview()
  if iv ~= nil then
    iv.info.pin:enable_widgets()
  end
end

---Disable widgets in the current infoview.
function infoview.disable_widgets()
  local iv = infoview.get_current_infoview()
  if iv ~= nil then
    iv.info.pin:disable_widgets()
  end
end

---Move the cursor to the infoview window.
---
----If the infoview is not open, it will be opened.
function infoview.go_to()
  infoview.open():enter()
end

---Move the current infoview to the appropriate spot based on the
---current screen dimensions.
---Does nothing if there are more than 2 open windows.
function infoview.reposition()
  local iv = infoview.get_current_infoview()
  if iv then
    iv:reposition()
  end
end

---Interactively set some view options for the infoview.
---
---Does not persist the selected options; if you wish to permanently affect
---which hypotheses are shown, set them in your lean.nvim configuration.
function infoview.select_view_options()
  infoview.open():select_view_options()
end

return infoview
