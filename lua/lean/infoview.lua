---@mod lean.infoview The Infoview

---@brief [[
--- Infoview-specific interaction for customizing or controlling the display of
--- Lean's interactive goal state.
---@brief ]]

local Buffer = require 'std.nvim.buffer'
local Window = require 'std.nvim.window'
local async = require 'std.async'
local throttle = require 'std.throttle'
local byte_col_to_utf16 = require('std.lsp').byte_col_to_utf16

local Element = require('lean.tui').Element
local Locations = require 'lean.infoview.locations'
local components = require 'lean.infoview.components'
local interactive_goal = require 'lean.widget.interactive_goal'
local log = require 'lean.log'
local progress = require 'lean.progress'
local rpc = require 'lean.rpc'

---Convert a buffer position to a human-readable (1, 1)-indexed string.
---Takes the workspace into account in order to return a relative path.
---@param buffer Buffer
---@param pos {integer, integer} 0-indexed { row, col } byte position
---@return string
local function position_to_string(buffer, pos)
  local workspace = vim.lsp.buf.list_workspace_folders()[1] or vim.uv.cwd()
  local filename = vim.uri_to_fname(buffer:uri())
  return ('%s at %d:%d'):format(
    vim.fs.relpath(workspace, filename) or filename,
    pos[1] + 1,
    pos[2] + 1
  )
end

---@param name string
---@return fun(element: Element): boolean?
local function has_name(name)
  return function(element)
    return element.name == name
  end
end

local is_goal = has_name 'goal-type'
local is_hypothesis = has_name 'hyp'
local is_suggestion = has_name 'suggestion'

local function is_link(element)
  local hlgroups = element.hlgroups
  return type(hlgroups) == 'table' and vim.tbl_contains(hlgroups, 'widgetLink')
end

local function is_trace_diagnostic(element)
  return element.events and element.events.trace_search
end

---Find the path to a descendant matching a predicate.
---
---When `reverse` is true, searches children in reverse order and returns
---the last (deepest, rightmost) match rather than the first.
---@param element Element the element to search within
---@param predicate fun(element: Element): boolean?
---@param path PathNode[] the path to `element` from the root
---@param reverse? boolean search in reverse order
---@return PathNode[]? path to the matching descendant
local function find_descendant_path(element, predicate, path, reverse)
  if predicate(element) then
    return path
  end
  local children = element:children():enumerate()
  if reverse then
    children = children:rev()
  end
  for idx, child in children do
    local child_path = vim.list_slice(path, 1, #path)
    table.insert(child_path, { idx = idx, name = child.name })
    local result = find_descendant_path(child, predicate, child_path, reverse)
    if result then
      return result
    end
  end
end

local contents_for_interactive, contents_for_plain

local infoview = {
  -- mapping from infoview IDs to infoviews
  ---@type table<number, Infoview>
  _by_tabpage = {},

  ---Whether to print additional debug information in the infoview.
  ---@type boolean
  debug = false,
}

---Run `fn(iv, ...)` if there's a current infoview; otherwise do nothing.
---@param fn fun(iv: Infoview, ...): any
local function with_current(fn, ...)
  local iv = infoview.get_current_infoview()
  if iv then
    return fn(iv, ...)
  end
end

---@type lean.infoview.Config
local options = {
  width = 1 / 3,
  height = 1 / 3,
  orientation = 'auto',
  horizontal_position = 'bottom',
  separate_tab = false,

  autoopen = true,
  update_cooldown = 50,
  indicators = 'auto',
  show_processing = true,
  show_no_info_message = false,

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

local FOCUS_AUGROUP = vim.api.nvim_create_augroup('LeanInfoviewFocus', {})

---@class InfoviewViewOptions
---@field use_widgets boolean use interactive widgets (true) or plain text (false)
---@field show_types boolean show type hypotheses
---@field show_instances boolean show instance hypotheses
---@field show_hidden_assumptions boolean show hypothesis names which are inaccessible
---@field show_let_values boolean show let-value bodies
---@field show_term_goals boolean show expected types?
---@field reverse boolean order hypotheses bottom-to-top

---An individual pin.
---@class Pin
---@field id string a label to identify the pin
---@field buffer Buffer the buffer for this pin's output
---@field window Window the window showing this pin's buffer
---@field private __data_element Element
---@field private __element Element
---@field private __extmark number
---@field private __extmark_buffer Buffer
---@field private __extmark_hl_group string
---@field private __extmark_virt_text table
---@field private __tick integer
---@field private __infoview Infoview
---@field private __renderer BufRenderer
---@field private __request_update fun(pin: Pin)
local Pin = { __extmark_ns = vim.api.nvim_create_namespace 'lean.pins' }
Pin.__index = Pin

local __next_buffer_id = 0

---A "view" on Lean goal state.
---@class Infoview
---@field pin Pin the main pin
---@field pins Pin[] additional pins
---@field last_window Window
---@field view_options InfoviewViewOptions
---@field private __auto_diff_pin boolean
---@field private __diff_pin Pin
---@field private __win_event_disable boolean
---@field private __last_trace_query string?
---@field private __contents_for fun(params: lsp.TextDocumentPositionParams, view_options: InfoviewViewOptions): Element
---@field window Window
---@field private __orientation "vertical"|"horizontal"
---@field private __orientation_pref "auto"|"vertical"|"horizontal"
---@field private __width number
---@field private __height number
---@field private __horizontal_position "top"|"bottom"
---@field private __separate_tab? boolean
local Infoview = {}
Infoview.__index = Infoview

---@class InfoviewNewArgs
---@field width? integer
---@field height? integer
---@field orientation? "auto"|"vertical"|"horizontal"
---@field horizontal_position? "top"|"bottom"
---@field separate_tab? boolean

---Resolve the dimensions from integer or fraction
---@param x number
---@param max number
local function res_dim(x, max)
  return (x < 1) and math.ceil(x * max) or x
end

---Set up infoview navigation keymaps on a pin buffer.
---@param buffer Buffer
function Infoview:__setup_pin_keymaps(buffer)
  local mappings = {
    {
      'GoToGoal',
      function()
        self:move_cursor_to_goal()
      end,
      '<LocalLeader>g',
      'Move to the first goal.',
    },
    {
      'NextGoal',
      function()
        self:__goto('next', is_goal)
      end,
      ']g',
      'Move to the next goal.',
    },
    {
      'PrevGoal',
      function()
        self:__goto('prev', is_goal)
      end,
      '[g',
      'Move to the previous goal.',
    },
    {
      'NextHypothesis',
      function()
        self:__goto('next', is_hypothesis)
      end,
      ']h',
      'Move to the next hypothesis.',
    },
    {
      'PrevHypothesis',
      function()
        self:__goto('prev', is_hypothesis)
      end,
      '[h',
      'Move to the previous hypothesis.',
    },
    {
      'GoToSuggestion',
      function()
        self:move_cursor_to_suggestion()
      end,
      '<LocalLeader>S',
      'Move to the first suggestion.',
    },
    {
      'AcceptSuggestion',
      function()
        self:accept_suggestion()
      end,
      '<LocalLeader>s',
      'Accept the first suggestion.',
    },
    {
      'NextSuggestion',
      function()
        self:__goto('next', is_suggestion)
      end,
      ']s',
      'Move to the next suggestion.',
    },
    {
      'PrevSuggestion',
      function()
        self:__goto('prev', is_suggestion)
      end,
      '[s',
      'Move to the previous suggestion.',
    },
    {
      'NextLink',
      function()
        self:__goto('next', is_link)
      end,
      ']l',
      'Move to the next link.',
    },
    {
      'PrevLink',
      function()
        self:__goto('prev', is_link)
      end,
      '[l',
      'Move to the previous link.',
    },
    {
      'TraceSearch',
      function()
        self:trace_search()
      end,
      '<LocalLeader>/',
      'Search through trace messages in the diagnostic under the cursor.',
    },
    {
      'NextTraceDiagnostic',
      function()
        self:__goto('next', is_trace_diagnostic)
      end,
      ']t',
      'Move to the next trace diagnostic.',
    },
    {
      'PrevTraceDiagnostic',
      function()
        self:__goto('prev', is_trace_diagnostic)
      end,
      '[t',
      'Move to the previous trace diagnostic.',
    },
    {
      'ViewOptions',
      function()
        self:select_view_options()
      end,
      '<LocalLeader>v',
      'Change the infoview view options.',
    },
  }

  for _, m in ipairs(mappings) do
    local plug = '<Plug>(LeanInfoview' .. m[1] .. ')'
    buffer.keymaps:set('n', plug, m[2], { desc = m[4] })
    buffer.keymaps:set('n', m[3], plug, { remap = true, desc = m[4] })
  end

  -- Show/hide current pin extmark when entering/leaving this pin's window.
  local pin_augroup = vim.api.nvim_create_augroup('LeanInfoviewShowPin', { clear = false })
  buffer:create_autocmd('WinEnter', {
    group = pin_augroup,
    callback = function()
      self:__maybe_show_pin_extmark 'current'
    end,
  })
  buffer:create_autocmd('WinLeave', {
    group = pin_augroup,
    callback = function()
      self.pin:__hide_extmark()
    end,
  })
end

---Create a new infoview.
---@param obj InfoviewNewArgs
---@return Infoview
function Infoview:new(obj)
  obj = obj or {}
  log:trace { message = 'creating new infoview', obj = obj }
  local config = require 'lean.config'
  local view_options = vim.deepcopy(config().infoview.view_options)
  local new_infoview = setmetatable({
    pins = {},
    __win_event_disable = false,
    view_options = view_options,
    __contents_for = view_options.use_widgets == false and contents_for_plain
      or contents_for_interactive,
    __orientation_pref = obj.orientation or options.orientation,
    __width = res_dim(obj.width or options.width, vim.o.columns),
    __height = res_dim(obj.height or options.height, vim.o.lines),
    __horizontal_position = obj.horizontal_position or options.horizontal_position,
    __separate_tab = obj.separate_tab or options.separate_tab,
  }, self)

  new_infoview.pin = Pin:new {
    id = '1',
    infoview = new_infoview,
  }

  new_infoview:__show_pin_in_main_window(new_infoview.pin)

  return new_infoview
end

---Show a pin's buffer in the main infoview window.
---@param pin Pin
function Infoview:__show_pin_in_main_window(pin)
  if self.window then
    self.__win_event_disable = true
    self.window.o.winfixbuf = false
    self.window:set_buffer(pin.buffer)
    pin.buffer.o.filetype = 'leaninfo'
    pin.window = self.window
    self.__win_event_disable = false
  end

  pin.buffer:create_autocmd('BufHidden', {
    group = vim.api.nvim_create_augroup('LeanInfoviewMainPin', { clear = false }),
    callback = function()
      if self.pin == pin then
        self:__was_closed()
      end
    end,
  })
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
  log:trace { message = 'opening infoview', id = self.window and self.window.id or nil }
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
      --        below we call `:make_current` immediately.
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
  self.window:set_buffer(self.pin.buffer)
  -- Set the filetype now. Any earlier, and only buffer-local options will be
  -- properly set in the infoview, since the buffer isn't actually shown in a
  -- window until we show it.
  self.pin.buffer.o.filetype = 'leaninfo'
  self.pin.window = self.window

  window_before_split:make_current()

  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(self.window.id),
    group = vim.api.nvim_create_augroup('LeanInfoviewClose', { clear = false }),
    once = true,
    callback = function()
      self:__was_closed()
    end,
  })

  -- Reopen windows for additional pins
  for _, pin in ipairs(self.pins) do
    if not pin.window or not pin.window:is_valid() then
      pin.window = self:__open_win(pin.buffer)
    end
  end

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
  self.window:set_height(res_dim(options.height, vim.o.lines))
end

---Move this infoview's window to the bottom of the tab, then size it properly.
function Infoview:move_to_bottom()
  self.window:call(function()
    vim.cmd.wincmd 'J'
  end)
  self.window:set_height(res_dim(options.height, vim.o.lines))
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
      self.window:set_height(res_dim(options.height, vim.o.lines))
    else
      self.window:set_width(res_dim(options.width, vim.o.columns))
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

---Jump to the given path in the current pin's renderer.
---@param path PathNode[]?
function Infoview:__jump_to_path(path)
  if not path then
    return
  end
  local renderer = self.pin.__renderer
  local pos = renderer:buf_position_from_path(path)
  if pos then
    self.window:set_cursor(pos)
    renderer:update_cursor(self.window)
  end
end

---Find the path to the nth element matching predicate.
---@param predicate fun(element: Element): boolean?
---@param n? integer defaults to 1
---@return PathNode[]?
function Infoview:__nth_path(predicate, n)
  if not self.window then
    return
  end
  local root = self.pin.__renderer.element
  local root_path = { { idx = 0, name = root.name } }
  local match = root:filter(predicate):nth(n or 1)
  if match then
    return find_descendant_path(root, function(e)
      return e == match
    end, root_path)
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
  local renderer = self.pin.__renderer
  local root = renderer.element
  local root_path = { { idx = 0, name = root.name } }

  -- Navigate semantically via the element tree when goals are available
  -- (interactive widgets). This handles any goal prefix, not just '⊢ '.
  for each_goal in root:filter(has_name 'interactive-goal') do
    local goal = each_goal:find(is_goal)
    if goal then
      n = n - 1
      if n == 0 then
        self:__jump_to_path(find_descendant_path(root, function(e)
          return e == goal
        end, root_path))
        return
      end
    end
  end

  -- Fallback for plain (non-widget) goals, or when the element tree
  -- hasn't been fully populated yet (e.g. still loading).
  for i, line in ipairs(renderer.buffer:lines()) do
    if line:find '^⊢ ' then
      n = n - 1
      if n == 0 then
        self.window:set_cursor { i, #'⊢ ' }
        renderer:update_cursor(self.window)
        return
      end
    end
  end
end

---Move the cursor to the nth suggestion.
---@param n? integer the suggestion number to move to, defaulting to the first
function Infoview:move_cursor_to_suggestion(n)
  self:__jump_to_path(self:__nth_path(is_suggestion, n))
end

---Accept (click) the nth suggestion.
---@param n? integer the suggestion number to accept, defaulting to the first
function Infoview:accept_suggestion(n)
  local path = self:__nth_path(is_suggestion, n)
  if path then
    self.pin.__renderer:event('click', path)
  end
end

---Search through trace messages in the diagnostic under the cursor.
---
---Prompts for a search query, then dispatches a `trace_search` event
---to highlight matching text within the trace. An empty query restores
---the original (unhighlighted) diagnostic message.
---
---The last query is remembered and pre-filled on the next invocation.
function Infoview:trace_search()
  if not self.window then
    return
  end

  local renderer = self.pin.__renderer
  if not renderer.path then
    return
  end

  local has_handler = renderer.element:find_innermost_along(renderer.path, function(_, element)
    return element.events and element.events.trace_search
  end)
  if not has_handler then
    vim.notify('No trace diagnostic under cursor.', vim.log.levels.INFO)
    return
  end

  vim.ui.input({ prompt = 'Trace search: ', default = self.__last_trace_query }, function(query)
    if query == nil then
      return
    end
    self.__last_trace_query = query ~= '' and query or nil
    renderer:event('trace_search', nil, query)
    if query ~= '' then
      vim.fn.setreg('/', query)
    end
  end)
end

---@alias NavigationDirection 'next' | 'prev'

---Move the cursor to the next or previous element matching a predicate.
---
---Walks up the element tree from the current cursor position, scanning
---through siblings at each level. Within each sibling, searches descendants
---for a match.
---@param direction NavigationDirection
---@param predicate fun(element: Element): boolean?
function Infoview:__goto(direction, predicate)
  if not self.window then
    return
  end
  local renderer = self.pin.__renderer
  if not renderer.path then
    return
  end
  local stack = renderer.element:div_from_path(renderer.path)
  if not stack then
    return
  end

  for level = #stack, 2, -1 do
    local parent = stack[level - 1]
    local current_idx = renderer.path[level].idx

    local children = parent:children():enumerate()
    if direction == 'prev' then
      children = children:rev()
    end

    local target_path
    children
      :filter(function(idx, _)
        if direction == 'next' then
          return idx > current_idx
        else
          return idx < current_idx
        end
      end)
      :find(function(idx, child)
        local base_path = vim.list_slice(renderer.path, 1, level - 1)
        table.insert(base_path, { idx = idx, name = child.name })
        target_path = find_descendant_path(child, predicate, base_path, direction == 'prev')
        return target_path
      end)

    if target_path then
      self:__jump_to_path(target_path)
      return
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
    {
      name = 'use widgets',
      description = 'Use interactive widgets or plain text goals?',
      option = 'use_widgets',
    },
  }

  require('lean.tui').select_many(choices, {
    format_item = function(item)
      return item.name
    end,
    tooltip_for = function(item)
      return item.description
    end,
    start_selected = function(choice)
      return self.view_options[choice.option]
    end,
    title = 'View Options',
    relative_window = self.window,
  }, function(selected, unselected)
    for each in vim.iter(selected) do
      self.view_options[each.option] = true
    end
    for each in vim.iter(unselected) do
      self.view_options[each.option] = false
    end
    self.__contents_for = self.view_options.use_widgets and contents_for_interactive
      or contents_for_plain
  end)
end

---Render the infoview contents for the given position.
---@param params lsp.TextDocumentPositionParams
---@return Element
function Infoview:render_contents(params)
  return self.__contents_for(params, self.view_options)
end

---Wait until the infoview has finished processing.
---@param timeout_ms? number the maximum time to wait, defaulting to 10s
function Infoview:wait(timeout_ms)
  timeout_ms = timeout_ms or 10000
  local pins = vim.list_extend({ self.pin, self.__diff_pin }, self.pins)
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

  self.__win_event_disable = true
  local window_before_split = Window:current()
  self:enter()

  if self.__orientation == 'vertical' then
    vim.cmd('leftabove ' .. self.__width .. 'vsplit')
  elseif self.__separate_tab then
    vim.cmd.tabnew()
  else
    vim.cmd('leftabove ' .. self.__height .. 'split')
  end
  local new_win = Window:current()
  if self.__orientation == 'vertical' then
    new_win:set_width(self.__width)
  elseif not self.__separate_tab then
    new_win:set_height(self.__height)
  end
  new_win:set_buffer(buffer)
  buffer.o.filetype = 'leaninfo'

  window_before_split:make_current()
  self.__win_event_disable = false

  return new_win
end

---Update the infoview window's winhighlight.
function Infoview:__update_winhighlight()
  if not self.window then
    return
  end

  if self.pin.paused then
    self.window.o.winhighlight = 'NormalNC:leanInfoPaused'
  else
    local params = self.pin.__position_params
    if params then
      local buffer = Buffer:from_uri(params.textDocument.uri)
      if buffer.b.lean_imports_out_of_date then
        self.window.o.winhighlight = 'NormalNC:leanInfoImportsOutOfDate'
      else
        self.window.o.winhighlight = ''
      end
    else
      self.window.o.winhighlight = ''
    end
  end
end

function Infoview:__resize_windows()
  log:debug { message = 'resizing infoview windows', window = self.window.id }

  local valid_windows = {}

  for _, win in pairs { self.window, self.__diff_pin and self.__diff_pin.window } do
    if win and win:is_valid() then
      table.insert(valid_windows, win)
    end
  end

  for _, win in pairs(valid_windows) do
    win.o.winfixwidth = true
  end

  for _, win in pairs(valid_windows) do
    if self.__orientation == 'vertical' then
      win:set_width(self.__width)
    elseif not self.__separate_tab then
      win:set_height(self.__height)
    end
  end
end

---Filter the pins from this infoview which are relevant to a given buffer.
---@param uri string the URI which filters the pins
---@return Pin[]
function Infoview:pins_for(uri)
  if not self.window then
    return {}
  end

  local possible = { self.pin }
  vim.list_extend(possible, self.pins)

  return vim
    .iter(possible)
    :filter(function(pin)
      return pin.__position_params and pin.__position_params.textDocument.uri == uri
    end)
    :totable()
end

function Infoview:__update()
  log:debug { message = 'updating infoview', window = self.window and self.window.id or nil }

  if self.__win_event_disable then
    return
  end
  self:update_last_window()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local buffer = Buffer:current()
  local pos = { cursor[1] - 1, cursor[2] }

  -- Update the diff pin first, while the extmark is still at the old
  -- position (it reads the extmark to get the "previous" location).
  if self.__auto_diff_pin then
    self:__update_auto_diff_pin(buffer, pos)
  end
  -- Move the extmark immediately so the pin indicator stays responsive,
  -- but throttle the LSP request + render so rapid cursor movement
  -- doesn't flood the server.
  self.pin:__update_extmark(buffer, pos)
  self.pin:request_update()
end

---Directly mark that the infoview has died. What a shame.
function Infoview:died()
  self.pin.__data_element = components.LSP_HAS_DIED
  local params = self.pin.__position_params
  progress.proc_infos[params.textDocument.uri] = {
    {
      kind = progress.Kind.fatal_error,
      range = { start = params.position, ['end'] = params.position },
    },
  }
  if self.window then
    self.window.o.winhighlight = 'NormalNC:leanInfoLSPDead'
  end
end

---Either open or close a diff window for this infoview depending on whether it has a diff pin.
function Infoview:__refresh_diff()
  if not self.window then
    return
  end

  if not self.__diff_pin then
    self:__close_diff()
    return
  end

  if not self.__diff_pin.window then
    self.__diff_pin.window = self:__open_win(self.__diff_pin.buffer)
  end

  for _, win in pairs { self.__diff_pin.window, self.window } do
    win:call(vim.cmd.diffthis)
    win.o.foldmethod = 'manual'
    win.o.wrap = true
  end

  self:__resize_windows()
end

---Close this infoview's diff window.
function Infoview:__close_diff()
  if not self.window then
    return
  end
  if not self.__diff_pin or not self.__diff_pin.window then
    return
  end

  self.window:call(function()
    vim.cmd.diffoff()
  end)

  local diff_win = self.__diff_pin.window
  self.__diff_pin.window = nil

  if diff_win:is_valid() then
    diff_win:call(function()
      vim.cmd.diffoff()
    end)
    self.__win_event_disable = true
    diff_win:force_close()
    self.__win_event_disable = false
  end

  self:__resize_windows()
end

---Close this infoview.
function Infoview:close()
  if not self.window then
    return
  end
  self:__close_diff()
  for _, pin in ipairs(self.pins) do
    pin:__close_window()
  end
  self.window:force_close()
  self:__was_closed()
end

function Infoview:__was_closed()
  if not self.window then
    return
  end
  self.window = nil
  self.pin.window = nil
  self.pin.__renderer:event 'clear_all' -- Ensure tooltips close.
end

---Retrieve the contents of the infoview as a table.
---@param start_line? number
---@param end_line? number
function Infoview:get_lines(start_line, end_line)
  if not self.window then
    error 'infoview is not open'
  end
  return self.pin:get_lines(start_line, end_line)
end

---Retrieve a specific line from the infoview window.
---@param line number
---@return string? line the infoview contents at the given line
function Infoview:get_line(line)
  if not self.window then
    error 'infoview is not open'
  end
  return self.pin:get_line(line)
end

---Retrieve the contents of the diff window as a table.
---@param start_line? number
---@param end_line? number
function Infoview:get_diff_lines(start_line, end_line)
  if not self.__diff_pin or not self.__diff_pin.window then
    error 'diff window is not open'
  end
  return self.__diff_pin:get_lines(start_line, end_line)
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
      callback = update_current_infoview,
      buffer = 0,
      group = vim.api.nvim_create_augroup('LeanInfoviewUpdate', {}),
    })
  end
end

function Infoview:add_pin()
  local buffer, pos = self.pin:__extmark_pos()
  local old_pin = self.pin
  table.insert(self.pins, old_pin)
  old_pin.window = self:__open_win(old_pin.buffer)
  self.pin = Pin:new {
    id = tostring(#self.pins + 1),
    infoview = self,
  }
  self:__show_pin_in_main_window(self.pin)
  old_pin:__show_extmark(old_pin.id)
  self:__maybe_show_pin_extmark(self.pin.id)
  if buffer then
    self.pin:move(buffer, pos)
  end
end

---@param buffer Buffer
---@param pos {integer, integer} 0-indexed { row, col } byte position
function Infoview:__set_diff_pin(buffer, pos)
  if not self.__diff_pin then
    self.__diff_pin = Pin:new {
      id = 'diff',
      infoview = self,
    }
    self.__diff_pin:__show_extmark(nil, 'leanDiffPinned')

    -- Make sure we notice even if someone manually :q's the diff window.
    self.__diff_pin.buffer:create_autocmd('BufHidden', {
      group = vim.api.nvim_create_augroup('LeanInfoviewClose', { clear = false }),
      callback = function()
        if not self.__win_event_disable then
          vim.schedule(function()
            self:__clear_diff_pin()
          end)
        end
      end,
    })
  end

  self.__diff_pin:move(buffer, pos)
  self:__refresh_diff()
end

function Infoview:clear_pins()
  for _, pin in pairs(self.pins) do
    pin:__teardown()
  end

  self.pins = {}
end

function Infoview:__clear_diff_pin()
  if not self.__diff_pin then
    return
  end
  self:__close_diff()
  local pin = self.__diff_pin
  self.__diff_pin = nil
  pin:__teardown()
end

---Show a pin extmark if it is appropriate based on configuration.
function Infoview:__maybe_show_pin_extmark(...)
  if not options.indicators or options.indicators == 'never' then
    return
  end
  -- self.pins is apparently all *other* pins, so we check it's empty
  if options.indicators == 'auto' and #self.pins == 0 then
    return
  end
  self.pin:__show_extmark(...)
end

---Set the current window as the last window used to update this infoview.
function Infoview:update_last_window()
  self.last_window = Window:current()
end

---Jump to the last window used to update this infoview, if any.
function Infoview:jump_to_last_window()
  if not self.last_window then
    return
  end
  self.last_window:make_current()
end

---Update the diff pin to use the current pin's position if it has one,
---and the provided position if it does not.
---@param buffer? Buffer
---@param pos? {integer, integer}
function Infoview:__update_auto_diff_pin(buffer, pos)
  local prev_buffer, prev_pos = self.pin:__extmark_pos()
  if prev_buffer then
    -- update diff pin to previous position
    self:__set_diff_pin(prev_buffer, prev_pos)
  elseif buffer then
    -- if no previous position, use current position
    self:__set_diff_pin(buffer, pos)
  end
end

---Toggle auto diff pin mode.
---@param clear boolean clear the pin when disabling auto diff pin mode?
function Infoview:__toggle_auto_diff_pin(clear)
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
  obj.paused = nil

  __next_buffer_id = __next_buffer_id + 1
  local pin_buffer = Buffer.create {
    name = 'lean://infoview/' .. __next_buffer_id,
    listed = false,
    scratch = true,
    options = { bufhidden = 'hide' },
  }

  local pin_element = Element:new { name = 'pin' }
  pin_element.events = {
    goto_last_window = function()
      obj.infoview:jump_to_last_window()
    end,
  }

  local pin_renderer = pin_element:renderer {
    buffer = pin_buffer,
    keymaps = options.mappings,
  }

  local new_pin = setmetatable(
    vim.tbl_extend('keep', obj, {
      paused = paused,
      __data_element = Element.EMPTY,
      __element = pin_element,
      __infoview = obj.infoview,
      __renderer = pin_renderer,
      __tick = 0,
      buffer = pin_buffer,
    }),
    self
  )
  new_pin.infoview = nil -- don't keep reference in this slot

  new_pin.__request_update = throttle(options.update_cooldown, function(pin)
    pin:update()
  end)

  new_pin.__infoview:__setup_pin_keymaps(pin_buffer)

  return new_pin
end

---Return all selectable elements within this pin.
---@return Iter
function Pin:selectable()
  return self.__data_element:filter(function(element)
    return element.events.select ~= nil
  end)
end

---Retrieve the contents of the pin as a table.
---@param start_line? number
---@param end_line? number
function Pin:get_lines(start_line, end_line)
  return self.buffer:lines(start_line, end_line)
end

---Retrieve a specific line from the pin buffer.
---@param line number
---@return string? line
function Pin:get_line(line)
  return self.buffer:line(line, false)
end

---Render this pin's element tree into its buffer.
function Pin:render()
  self.__renderer:render()
end

---Close this pin's window if it has one.
function Pin:__close_window()
  if self.window and self.window:is_valid() then
    self.window:force_close()
  end
  self.window = nil
end

function Pin:__teardown()
  self:__close_window()
  local extmark = self.__extmark
  local extmark_buffer = self.__extmark_buffer
  self.__infoview = nil
  if extmark then
    pcall(function()
      extmark_buffer:del_extmark(self.__extmark_ns, extmark)
    end)
  end
  self.__renderer:close()
end

---Update pin extmark based on position, used when resetting pin position.
---@param buffer Buffer
---@param pos {integer, integer} 0-indexed { row, col } byte position
function Pin:__update_extmark(buffer, pos)
  if not buffer:is_loaded() then
    return
  end

  self:__update_extmark_style(buffer, pos[1], pos[2])

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
    local extmark_pos = buffer:extmark(self.__extmark_ns, self.__extmark, {})
    if vim.tbl_isempty(extmark_pos) then
      return
    end
    line = extmark_pos[1]
    col = extmark_pos[2]
  end

  -- Highlight exactly one character: find the byte position of the next
  -- codepoint after `col`. vim.str_utfindex rounds up if `col` is in the
  -- middle of a UTF-8 sequence, so converting col+1 → UTF-16 → byte gives
  -- us the start of the *next* codepoint.
  local buf_line = buffer:line(line, false)
  local end_col = col
  if not buf_line then
    end_col = 0
  elseif col < #buf_line then
    end_col = vim.str_byteindex(buf_line, 'utf-16', byte_col_to_utf16(buf_line, col + 1))
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

  local extmark_pos = buffer:extmark(self.__extmark_ns, extmark, {})
  local new_pos = {
    line = extmark_pos[1],
    character = byte_col_to_utf16(buffer:line(extmark_pos[1], false), extmark_pos[2]),
  }
  local uri = buffer:uri()
  ---@type lsp.TextDocumentPositionParams
  self.__position_params = { textDocument = { uri = uri }, position = new_pos }

  pcall(
    vim.api.nvim_buf_set_name,
    self.buffer.bufnr,
    'lean://infoview/' .. position_to_string(buffer, extmark_pos)
  )
end

---Return the current pin position read directly from the extmark.
---Returns nil if the pin has no extmark or the buffer is unloaded.
---@return Buffer? buffer
---@return {integer, integer}? pos 0-indexed { row, col } byte position
function Pin:__extmark_pos()
  if not self.__extmark then
    return
  end
  local buffer = self.__extmark_buffer
  if not buffer:is_loaded() then
    return
  end
  local pos = buffer:extmark(self.__extmark_ns, self.__extmark, {})
  if vim.tbl_isempty(pos) then
    return
  end
  return buffer, pos
end

function Pin:__show_extmark(name, hlgroup)
  self.__extmark_hl_group = hlgroup or 'leanPinned'
  if name then
    self.__extmark_virt_text = { { '← ' .. name, 'Comment' } }
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
  self.__infoview:__update_winhighlight()
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

---Request a throttled update of this pin.
function Pin:request_update()
  if self.paused then
    self.__infoview:__update_winhighlight()
    return
  end
  self.__request_update(self)
end

---@param buffer Buffer
---@param pos {integer, integer} 0-indexed { row, col } byte position
function Pin:move(buffer, pos)
  self:__update_extmark(buffer, pos)
  self:request_update()
end

---Wrap content blocks with a clear_all event handler.
---
---@param blocks Element[]
---@param params lsp.TextDocumentPositionParams
---@return Element
local function wrap_content_blocks(blocks, params)
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

---Handle the processing and fatal_error states, returning an element if
---applicable. When Lean is still working, we show a processing indicator
---and top-of-file diagnostics; on fatal error, we show line diagnostics.
---
---@param params lsp.TextDocumentPositionParams
---@return Element? element if processing state was handled
local function contents_for_processing(params)
  local processing = progress.at(params)
  if processing == progress.Kind.processing then
    ---@type lsp.TextDocumentPositionParams
    local start = {
      textDocument = params.textDocument,
      position = { line = 1, character = 0 },
    }
    local blocks = vim
      .iter({
        { options.show_processing and components.PROCESSING or nil },
        interactive_goal.diagnostics(start),
      })
      :flatten(1)
    return Element:concat(blocks:totable(), '\n\n') or Element.EMPTY
  end

  if processing == progress.Kind.fatal_error then
    log:debug {
      message = 'progress.Kind.fatal_error diagnostics',
      params = params,
    }
    return wrap_content_blocks(interactive_goal.diagnostics(params), params)
  end
end

---Render the combined contents of the infoview using interactive widgets.
---
---@param params lsp.TextDocumentPositionParams
---@param view_options InfoviewViewOptions
---@return Element
function contents_for_interactive(params, view_options)
  local element = contents_for_processing(params)
  if element then
    return element
  end

  local sess = rpc.open(params)

  local blocks = vim
    .iter({
      components.goal_at(sess, view_options) or {},
      view_options.show_term_goals and components.term_goal_at(sess, view_options) or {},
      components.user_widgets_at(sess) or {},
      components.diagnostics_at(sess) or {},
    })
    :flatten(1)
    :totable()

  return wrap_content_blocks(blocks, params)
end

---Render the combined contents of the infoview using plain text.
---
---@param params lsp.TextDocumentPositionParams
---@param view_options InfoviewViewOptions
---@return Element
function contents_for_plain(params, view_options)
  local element = contents_for_processing(params)
  if element then
    return element
  end

  local plain = require 'lean.infoview.plain'

  local blocks = vim
    .iter({
      components.plain_goal_at(params) or {},
      view_options.show_term_goals and plain.term_goal(params) or {},
      interactive_goal.diagnostics(params) or {},
    })
    :flatten(1)
    :totable()

  return wrap_content_blocks(blocks, params)
end

function Pin:update()
  async.run(function()
    log:trace { message = 'updating pin', id = self.id, paused = self.paused, loading = self.loading }
    local iv = self.__infoview
    if not iv.window then
      return
    end
    if self.paused then
      iv:__update_winhighlight()
      return
    end

    local params = self.__position_params
    if not params or not Buffer:from_uri(params.textDocument.uri):is_loaded() then
      return
    end

    iv:__update_winhighlight()

    if not self.loading then
      self.loading = true
      self:render()
    end

    self.__tick = self.__tick + 1
    local tick = self.__tick

    self.__data_element = iv:render_contents(params)
    if self.__data_element == components.LSP_HAS_DIED then
      iv.window.o.winhighlight = 'NormalNC:leanInfoLSPDead'
    end

    if self.__tick ~= tick or not self.__infoview then
      return
    end

    self.loading = false
    self.__element:set_children { self.__data_element }
    iv.__last_trace_query = nil
    self:render()

    if iv.window and not iv.window:is_current() and self == iv.pin then
      iv:move_cursor_to_goal()
    end

    iv:__refresh_diff()
  end)
end

---Close all open infoviews (across all tabs).
function infoview.close_all()
  for _, each in pairs(infoview._by_tabpage) do
    each:close()
  end
end

---@private
---Throttled update of all pins for a URI.
function infoview.__update_pin_by_uri(uri)
  for _, each in pairs(infoview._by_tabpage) do
    for _, pin in pairs(each:pins_for(uri)) do
      pin:request_update()
    end
  end
end

---@private
---Called by the $/lean/fileProgress handler.
---Skips updates only when the pin's position is not being processed
---and was already not being processed on the last notification.
---During processing, every notification may carry new diagnostics
---(e.g. lake build output) worth re-rendering.
function infoview.__on_file_progress(uri)
  for _, each in pairs(infoview._by_tabpage) do
    for _, pin in pairs(each:pins_for(uri)) do
      local current = progress.at(pin.__position_params)
      if current ~= nil or pin.__last_processing ~= nil then
        pin.__last_processing = current
        pin:request_update()
      end
    end
  end
end

---@private
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

      -- in case we are re-entering a buffer, clear old autocmds first
      vim.api.nvim_clear_autocmds { group = FOCUS_AUGROUP, buffer = bufnr }

      vim.api.nvim_create_autocmd('LspDetach', {
        callback = function()
          local current_infoview = infoview.get_current_infoview()
          if not current_infoview then
            return
          end
          current_infoview:died()
        end,
        buffer = bufnr,
        group = FOCUS_AUGROUP,
      })

      vim.api.nvim_create_autocmd('BufEnter', {
        callback = infoview_bufenter,
        buffer = bufnr,
        group = FOCUS_AUGROUP,
      })

      -- WinEnter is necessary for the edge case where you have
      -- a file open in a tab with an infoview and move to a
      -- new window in a new tab with that same file but no infoview
      vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
        callback = function()
          local current_infoview = infoview.get_current_infoview()
          if not current_infoview then
            return
          end
          current_infoview:focus_on_current_buffer()
        end,
        buffer = bufnr,
        group = FOCUS_AUGROUP,
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
  with_current(Infoview.close)
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
  with_current(function(iv)
    iv.pin:toggle_pause()
  end)
end

---Open the infoview from the current Lean buffer, recording the buffer's
---window so the infoview can later jump back.
---@return Infoview?
local function open_for_current_lean_buffer()
  if vim.bo.filetype ~= 'lean' then
    return
  end
  local iv = infoview.open()
  iv:update_last_window()
  return iv
end

---Add a pin to the current cursor location.
function infoview.add_pin()
  local iv = open_for_current_lean_buffer()
  if iv then
    iv:add_pin()
  end
end

---Set the location for a diff pin to the current cursor location.
function infoview.set_diff_pin()
  local iv = open_for_current_lean_buffer()
  if iv then
    local cursor = vim.api.nvim_win_get_cursor(0)
    iv:__set_diff_pin(Buffer:current(), { cursor[1] - 1, cursor[2] })
  end
end

---Clear any pins in the current infoview.
function infoview.clear_pins()
  with_current(Infoview.clear_pins)
end

---Clear a diff pin in the current infoview.
function infoview.clear_diff_pin()
  with_current(Infoview.__clear_diff_pin)
end

---Toggle whether "auto-diff" mode is active for the current infoview.
function infoview.toggle_auto_diff_pin(clear)
  if vim.bo.filetype ~= 'lean' then
    return
  end
  local current_infoview = infoview.open()
  current_infoview:__toggle_auto_diff_pin(clear)
end

local function set_renderer(contents_for, use_widgets)
  with_current(function(iv)
    iv.view_options.use_widgets = use_widgets
    iv.__contents_for = contents_for
    iv.pin:update()
  end)
end

---Enable widgets in the current infoview.
function infoview.enable_widgets()
  set_renderer(contents_for_interactive, true)
end

---Disable widgets in the current infoview.
function infoview.disable_widgets()
  set_renderer(contents_for_plain, false)
end

---Move the cursor to the infoview window.
---
---If the infoview is not open, it will be opened.
function infoview.go_to()
  infoview.open():enter()
end

---Move the current infoview to the appropriate spot based on the
---current screen dimensions.
---Does nothing if there are more than 2 open windows.
function infoview.reposition()
  with_current(Infoview.reposition)
end

---Interactively set some view options for the infoview.
---
---Does not persist the selected options; if you wish to permanently affect
---which hypotheses are shown, set them in your lean.nvim configuration.
function infoview.select_view_options()
  infoview.open():select_view_options()
end

---Move the infoview cursor to the given goal.
---@param n? integer the goal number to move to, defaulting to the first
function infoview.go_to_goal(n)
  with_current(Infoview.move_cursor_to_goal, n)
end

---Move the infoview cursor to the given suggestion.
---@param n? integer the suggestion number to move to, defaulting to the first
function infoview.go_to_suggestion(n)
  with_current(Infoview.move_cursor_to_suggestion, n)
end

---Accept (click) the given suggestion.
---@param n? integer the suggestion number to accept, defaulting to the first
function infoview.accept_suggestion(n)
  with_current(Infoview.accept_suggestion, n)
end

local function goto_step(direction, predicate)
  return function()
    with_current(Infoview.__goto, direction, predicate)
  end
end

---Move the infoview cursor to the next goal.
infoview.next_goal = goto_step('next', is_goal)
---Move the infoview cursor to the previous goal.
infoview.prev_goal = goto_step('prev', is_goal)
---Move the infoview cursor to the next hypothesis.
infoview.next_hypothesis = goto_step('next', is_hypothesis)
---Move the infoview cursor to the previous hypothesis.
infoview.prev_hypothesis = goto_step('prev', is_hypothesis)
---Move the infoview cursor to the next suggestion.
infoview.next_suggestion = goto_step('next', is_suggestion)
---Move the infoview cursor to the previous suggestion.
infoview.prev_suggestion = goto_step('prev', is_suggestion)
---Move the infoview cursor to the next link.
infoview.next_link = goto_step('next', is_link)
---Move the infoview cursor to the previous link.
infoview.prev_link = goto_step('prev', is_link)

---@class infoview.ContentsAtOpts
---@field buf? integer buffer handle, defaulting to the current buffer
---@field callback? fun(element: Element) called with the result for async use
---@field timeout? integer timeout in ms for the synchronous case (default: 10000)

---Return the infoview contents at the given position.
---
---When called with a callback, runs asynchronously and passes the Element to
---the callback. When called without one, blocks until the result is ready
---(waiting for the file to finish processing at the given position).
---
---@param position { [1]: integer, [2]: integer } a (1, 0)-indexed cursor position (as in `nvim_win_set_cursor`)
---@param opts? infoview.ContentsAtOpts
---@return Element? element the result, only when called synchronously
function infoview.contents_at(position, opts)
  vim.validate('position', position, 'table')
  opts = opts or {}
  vim.validate('opts', opts, 'table')

  local buf = Buffer:from_bufnr(opts.buf or 0)
  local callback = opts.callback

  local line = position[1] - 1
  local col = position[2]

  ---@type lsp.TextDocumentPositionParams
  local position_params = {
    textDocument = { uri = buf:uri() },
    position = {
      line = line,
      character = byte_col_to_utf16(buf:line(line, false), col),
    },
  }

  local iv = infoview.get_current_infoview()
  if not iv then
    error 'infoview.contents_at: no infoview is open'
  end

  ---Wait for processing to finish at the given position, then fetch contents.
  local function fetch()
    while progress.at(position_params) do
      local event = async.event()
      local autocmd
      autocmd = vim.api.nvim_create_autocmd('User', {
        pattern = progress.AUTOCMD,
        once = true,
        callback = function()
          autocmd = nil
          event.set()
        end,
      })
      -- Check again in case processing finished between the while check and
      -- the autocmd registration.
      if not progress.at(position_params) then
        if autocmd then
          vim.api.nvim_del_autocmd(autocmd)
        end
        break
      end
      event.wait()
    end
    return iv:render_contents(position_params)
  end

  if callback then
    async.run(function()
      callback(fetch())
    end)
    return
  end

  local timeout = opts.timeout or 10000
  local result
  async.run(function()
    result = fetch()
  end)
  local succeeded = vim.wait(timeout, function()
    return result ~= nil
  end)
  if not succeeded then
    error(('infoview.contents_at: timed out after %dms waiting for contents'):format(timeout))
  end
  return result
end

return infoview
