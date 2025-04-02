local async = require 'plenary.async'

local log = require 'lean.log'
local util = require 'lean._util'

---A fire-able event whose behavior is `Element`-specific.
---
---An element can define how to handle the event, as well as which keyboard
---keys trigger it (or theoretically mouse events, though we don't do so in
---practice at the moment).
---
---In general, resist the temptation to add new event types here, as this
---entire concept feels slightly like "misdirection" that could be redesigned
---at least because it mixes abstraction layers between general events and ones
---that are very specific to a particular context (like "going to the last
---window").
---
---The values here are our typical mappings for this event.
---events unless there's specific reason not to (e.g. bind clicking to `<CR>`).
---This "standard keymap" itself seems like a reason we need to revisit events
---(because we can likely represent the default key for each event here
---somehow).
---@alias ElementEvent
---| '"click"' # Click on the element.
---
---| '"clear"' # Clear the element.
---| '"clear_all"' # Clear the element and all "related" ones.
---
---| '"goto_last_window"' # Move the cursor to the last window it was in.
---
---| '"go_to_def"' # Go to the definition of the element contents.
---| '"go_to_decl"' # Go to the declaration of the element contents.
---| '"go_to_type"' # Go to the type definition of the element contents.

---@alias EventCallbacks { [ElementEvent]: fun(ctx: ElementEventContext, ...:any):boolean? }

---An individual console user interface element.
---@class Element
---@field events EventCallbacks functions to fire for events which this element responds to
---@field text string the text to show when rendering this element
---@field name string a named handle for this element, used when path-searching
---@field hlgroup? string|fun(string):string the highlight group for this element's text, or a function that returns it
---@field tooltip? Element? tooltip
---@field highlightable boolean (for buffer rendering) whether to highlight this element when hovering over it
---@field _size? integer Computed size of this element, updated by `Element:to_string`
---@field private __children Element[] this element's children
local Element = {}
Element.__index = Element

---Renders elements within a specific buffer.
---@class BufRenderer
---@field buf integer Buffer number of the buffer the element renders to
---@field element Element the element rendered by this renderer
---@field lines? string[] Rendered lines.
---@field path? PathNode[] Current cursor path
---@field last_win? integer Window number of the last event
---@field last_win_options? table When used as a tooltip, the window options.
---@field keymaps table Extra keymaps (inherited by tooltips)
---@field hover_range? integer[][] (0,0)-range of the highlighted node
---@field tooltip? BufRenderer currently open tooltip
---@field parent? BufRenderer Parent renderer
---@field parent_path? PathNode[] Path in parent element, events bubble up to the parent there
local BufRenderer = {
  __tui_ns = vim.api.nvim_create_namespace 'lean.tui',
  __hl_ns = vim.api.nvim_create_namespace 'lean.highlights',
}
BufRenderer.__index = BufRenderer

---@class ElementNewArgs
---@field events? EventCallbacks event function map
---@field text? string the text to show when rendering this element
---@field name? string a named handle for this element, used when path-searching
---@field hlgroup? string|fun():string the highlight group for this element's text, or a function that returns it
---@field highlightable boolean? (for buffer rendering) whether to highlight this element when hovering over it
---@field children? Element[] this element's children

---Create a new Element.
---@param args? ElementNewArgs
---@return Element
function Element:new(args)
  args = args or {}
  local obj = {
    text = args.text or '',
    name = args.name or '',
    hlgroup = args.hlgroup,
    highlightable = args.highlightable or false,
    __children = args.children or {},
    events = args.events or {},
  }
  return setmetatable(obj, self)
end

---@class ElementNewBoxArgs
---@field title string the heading for this box
---@field titlehl string? the highlight group for the title
---@field children? Element[] the children for the body of this box

---Create a new element with a heading and body.
---@param args ElementNewBoxArgs
---@return Element
function Element.box(args)
  local element = Element:new {
    text = ('▼ %s:\n'):format(args.title),
    hlgroup = args.titlehl or 'Title',
  }
  local children = { element }
  vim.list_extend(children, args.children)
  return Element:new { children = children }
end

---Create an Element whose click event does nothing.
---@param text string? the text to show when rendering this element
---@return Element
function Element.noop(text)
  local noop = function() end
  return Element:new {
    text = text,
    events = { click = noop },
  }
end

---The empty element (with no content).
Element.EMPTY = Element:new {}

---@param children? Element[]
function Element:set_children(children)
  self.__children = children or {}
end

---Add a child to this element.
---@param child Element child element to add
---@return nil
function Element:add_child(child)
  table.insert(self.__children, child)
end

---Set this element's tooltip.
---@param element Element element to use as a tooltip for this element
---@return Element the added tooltip element
function Element:add_tooltip(element)
  self.tooltip = element
  return element
end

---Remove this element's tooltip.
---@return nil
function Element:remove_tooltip()
  self.tooltip = nil
end

---@class ElementHighlight
---@field start integer
---@field end integer
---@field hlgroup string

---@return ElementHighlight[]
function Element:_get_highlights()
  local hls = {} ---@type ElementHighlight[]

  ---@param element Element
  ---@param pos integer
  local function go(element, pos)
    local hlgroup = element.hlgroup
    if type(hlgroup) == 'function' then
      hlgroup = hlgroup(element)
    end
    if hlgroup then
      table.insert(hls, {
        start = pos,
        ['end'] = pos + element._size,
        hlgroup = hlgroup,
      })
    end

    pos = pos + #element.text
    for _, child in ipairs(element.__children) do
      go(child, pos)
      pos = pos + child._size
    end
  end

  go(self, 1)

  return hls
end

---Render the element into a string.
---@return string
function Element:to_string()
  local pieces = {}
  ---@param element Element
  local function go(element)
    table.insert(pieces, element.text)
    local size = #element.text
    for _, child in ipairs(element.__children) do
      go(child)
      size = size + child._size
    end
    element._size = size
  end
  go(self)
  return table.concat(pieces)
end

---Return true if the element renders into the empty string.
---@return boolean
function Element:is_empty()
  return #self:to_string() == 0
end

---Represents a node in a path through an element.
---@class PathNode
---@field idx number the index in the current element's children to follow
---@field name string the name that the indexed child should have
---@field offset number? if provided, a byte offset from the beginning of this element

---Get the raw byte position of the element arrived at by following the given path.
---@param path PathNode[] the path to follow
---@return number? the position if the path was valid, nil otherwise
---@return number? the additional byte offset from the position if the path was valid, nil otherwise
function Element:pos_from_path(path)
  local pos = 1
  for i, p in ipairs(path) do
    if i == 1 then -- first path node encodes root
      if p.name ~= self.name then
        return nil
      end
    else
      if #self.__children < p.idx then
        return nil
      end
      pos = pos + #self.text
      for j = 1, p.idx - 1 do
        pos = pos + self.__children[j]._size
      end
      self = self.__children[p.idx]
    end
  end
  local offset = path[#path].offset or 0
  -- in case this is an invalid or outdated path
  local maybe_offset = (#self.text - 1 >= offset) and offset
  offset = maybe_offset or 0
  return pos, offset
end

---Get the element stack and element arrived at by following the given path.
---@param path PathNode[] the path to follow
---@return Element[]? the stack of elements at this path, or nil if the path is invalid
---@return Element? the element at this path, or nil if the path is invalid
function Element:div_from_path(path)
  local stack = { self }
  for i, p in ipairs(path) do
    if i == 1 then -- first path node encodes root
      if p.name ~= self.name then
        return nil, nil
      end
    else
      if #self.__children < p.idx then
        return nil, nil
      end
      self = self.__children[p.idx]
      table.insert(stack, self)
    end
  end
  return stack, self
end

---@generic T
---@param arr T[]
---@param n integer
---@return T[]
local function take(arr, n)
  local res = {}
  for i = 1, n do
    table.insert(res, arr[i])
  end
  return res
end

---Find the innermost element satisfying a predicate.
---@param path PathNode[]
---@param check fun(element:Element):any
---@return Element found The element satisfying check
---@return Element[] stack The element stack up to and including that element
---@return PathNode[] subpath The subpath up to that element
---@overload fun(path: PathNode[], check):nil if no element is found
function Element:find_innermost_along(path, check)
  local stack, _ = self:div_from_path(path)
  if stack == nil then
    return
  end

  for i = #stack, 1, -1 do
    local this_element = stack[i]
    if check(this_element) then
      return this_element, take(stack, i), take(path, i)
    end
  end
end

local function pos_to_raw_pos(pos, lines)
  local raw_pos = 0
  for i = 1, pos[1] - 1 do
    if not lines[i] then
      return
    end
    raw_pos = raw_pos + #lines[i] + 1
  end
  if
    not lines[pos[1]]
    or (#lines[pos[1]] == 0 and pos[2] ~= 0)
    or (#lines[pos[1]] > 0 and pos[2] + 1 > #lines[pos[1]])
  then
    return
  end
  raw_pos = raw_pos + pos[2] + 1
  return raw_pos
end

---Return (0, 0)-indexed cursor position from raw byte position and list of lines
local function raw_pos_to_pos(raw_pos, lines)
  local line_num = 0
  local rem_chars = raw_pos

  for _, line in ipairs(lines) do
    line_num = line_num + 1
    if rem_chars <= (#line + 1) then
      return { line_num - 1, rem_chars - 1 }
    end

    rem_chars = rem_chars - (#line + 1)
  end
end

---Get the path at the given raw byte position.
---(requires previous call to Element:to_string)
---@param pos integer byte position
---@return PathNode[]? the path at this position
---@return Element[]? the stack of elements along this path
function Element:path_from_pos(pos)
  local path = { { idx = 0, name = self.name } }
  local stack = { self }
  pos = pos - 1
  ::next::
  if pos < #self.text then
    path[#path].offset = pos
    return path, stack
  end
  pos = pos - #self.text
  for idx, child in ipairs(self.__children) do
    if child._size == nil then
      return nil
    end
    if pos < child._size then
      table.insert(path, { idx = idx, name = child.name })
      table.insert(stack, child)
      self = child
      goto next
    else
      pos = pos - child._size
    end
  end
  return nil
end

---Trigger the given event at the given path
---@param path PathNode[] the path to trigger the event at
---@param event ElementEvent the event to fire
function Element:event(path, event, ...)
  local event_element = self:find_innermost_along(path, function(element)
    return element.events and element.events[event]
  end)
  if not event_element then
    return false
  end

  local args = { ... }

  async.void(function()
    return event_element.events[event](unpack(args))
  end)()
  return true
end

---Returns the first element matching the given check function.
---Searches first this element itself, then its children, then its tooltip.
---@param check fun(element:Element):boolean?
function Element:find(check)
  if check(self) then
    return self
  end

  local found
  for _, child in ipairs(self.__children) do
    found = child:find(check)
    if found then
      return found
    end
  end

  if self.tooltip then
    found = self.tooltip:find(check)
    if found then
      return found
    end
  end
end

function Element:__filter(path, pos, fn)
  pos = pos + #self.text

  for idx, child in ipairs(self.__children) do
    local new_path = { unpack(path) }
    table.insert(new_path, { idx = idx, name = child.name })
    fn(child, new_path, pos)

    pos = child:__filter(new_path, pos, fn)
  end

  return pos
end

function Element:filter(fn)
  local path = { { idx = -1, name = self.name } }
  local pos = 1
  fn(self, path, pos)

  self:__filter(path, pos, fn)
end

---@class TitledElementArgs
---@field title string
---@field body Element[]?
---@field title_hlgroup? string the hlgroup to use for the element's title

---Create an element with optional title and body contents.
---@param opts TitledElementArgs
---@return Element?
function Element:titled(opts)
  local body = opts.body
          and #opts.body > 0
          and self:new { children = opts.body }
           or nil

  if opts.title == '' then
    return body
  end

  local title = self:new { text = opts.title, hlgroup = opts.title_hlgroup }

  if not body then
    return title
  end

  local sep = self:new { text = '\n\n' }
  return self:new { children = { title, sep, body } }
end

---Create an element which joins a list-like table of elements with the provided separator.
---@param elements Element[]
---@param sep string
---@param opts ElementNewArgs?
---@return Element?
function Element:concat(elements, sep, opts)
  if #elements == 0 then
    return
  elseif #elements == 1 then
    return elements[1]
  end
  local separator = Element:new{ text = sep }
  return self:new(
    vim.tbl_extend('error', opts or {}, {
      children = vim.iter(elements):fold(nil, function(acc, k)
        if not acc then return { k } end
        table.insert(acc, separator)
        table.insert(acc, k)
        return acc
      end)
    })
  )
end

---Create a BufRenderer that renders this Element.
---@param obj table
function Element:renderer(obj)
  return BufRenderer:new(vim.tbl_extend('error', obj, { element = self }))
end

---Create a new BufRenderer.
function BufRenderer:new(obj)
  obj = obj or {}
  local new_renderer = setmetatable(obj, self)
  vim.bo[obj.buf].modifiable = false

  vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorMoved' }, {
    group = vim.api.nvim_create_augroup('WidgetPosition', { clear = false }),
    buffer = obj.buf,
    callback = function()
      new_renderer:update_cursor()
    end,
  })

  -- Note that only closures work here, we can't go storing this on vim.b due
  -- to neovim/neovim#12544 wherein the metatable would be lost on retrieval.
  -- In other words, if we do vim.b[..].foo = new_renderer, when we come back
  -- to look at it, it's not a BufRenderer anymore. Surprise!
  vim.keymap.set('n', '<Tab>', function()
    new_renderer:enter_tooltip()
  end, { buffer = obj.buf, desc = 'Enter a tooltip.' })
  vim.keymap.set('n', 'J', function()
    new_renderer:enter_tooltip()
  end, { buffer = obj.buf, desc = 'Enter a tooltip.' })
  vim.keymap.set('n', '<S-Tab>', function()
    new_renderer:goto_parent_tooltip()
  end, { buffer = obj.buf, desc = 'Go to the "parent" tooltip.' })
  vim.keymap.set(
    'n',
    '<LocalLeader>\\',
    require'lean.abbreviations'.show_reverse_lookup,
    { buffer = obj.buf, desc = 'Show how to type the unicode character under the cursor.' }
  )

  for key, event in pairs(obj.keymaps or {}) do
    vim.keymap.set('n', key, function()
      new_renderer:event(event)
    end, { buffer = obj.buf, desc = ('Fire a %s event.'):format(event) })
  end

  return new_renderer
end

---@param keep_tooltips_open? boolean
function BufRenderer:close(keep_tooltips_open)
  if vim.api.nvim_buf_is_loaded(self.buf) then
    vim.api.nvim_buf_delete(self.buf, { force = true })
  end
  if self.tooltip then
    self.tooltip.parent = nil
    self.tooltip.parent_path = nil
    if not keep_tooltips_open then
      self.tooltip:close()
      self.tooltip = nil
    end
  end
end

function BufRenderer:render()
  local buf = self.buf

  if not vim.api.nvim_buf_is_loaded(buf) then
    log:warning { message = 'rendering an unloaded buffer', buf = buf }
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, self.__tui_ns, 0, -1)

  local text = self.element:to_string()
  local lines = vim.split(text, '\n')
  self.lines = lines

  vim.bo[buf].modifiable = true
  -- XXX: Again I do not understand why tests occasionally are flaky,
  --      complaining about invalid buffer names, if we don't have this pcall.
  local ok, _ = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
  if not ok then
    require 'lean.log':error { message = 'infoview failed to update', buf = buf }
  end
  vim.bo[buf].modifiable = false

  for _, hl in ipairs(self.element:_get_highlights()) do
    local start_pos = raw_pos_to_pos(hl.start, lines)
    local end_pos = raw_pos_to_pos(hl['end'], lines)
    vim.highlight.range(buf, self.__tui_ns, hl.hlgroup, start_pos, end_pos)
  end

  if self.path then
    -- on a rerender any previously existing paths may be invalid
    -- TODO: cache div_from_path() return value to use in hover()
    if not self.element:div_from_path(self.path) then
      self.path = nil
    elseif self:last_win_valid() then
      local raw_pos, offset = self.element:pos_from_path(self.path)
      local pos = raw_pos_to_pos(raw_pos + offset, lines)
      pos[1] = pos[1] + 1
      vim.api.nvim_win_set_cursor(self.last_win, pos)
    end
  end

  self:hover(true)
end

function BufRenderer:enter_tooltip()
  if self.tooltip and self.tooltip:last_win_valid() then
    vim.api.nvim_set_current_win(self.tooltip.last_win)
  end
end

function BufRenderer:goto_parent_tooltip()
  if self.parent and self.parent:last_win_valid() then
    vim.api.nvim_set_current_win(self.parent.last_win)
  end
end

function BufRenderer:last_win_valid()
  return self.last_win
    and vim.api.nvim_win_is_valid(self.last_win)
    and vim.api.nvim_win_get_buf(self.last_win) == self.buf
end

function BufRenderer:update_cursor(win)
  win = win or vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) == self.buf then
    self.last_win = win
  end
  if not self:last_win_valid() then
    return
  end

  local path_changed = self:update_position()

  if path_changed then
    self:hover()
  end
end

---Checks if two paths are equal, ignoring auxillary metadata (e.g. offsets)
---@param path_a PathNode[]? first path
---@param path_b PathNode[]? second path
local function path_equal(path_a, path_b)
  if path_a == nil and path_b == nil then
    return true
  end
  if not path_a or not path_b then
    return false
  end
  if #path_a ~= #path_b then
    return false
  end

  for i, _ in ipairs(path_a) do
    if path_a[i].idx ~= path_b[i].idx then
      return false
    end
    if path_a[i].name ~= path_b[i].name then
      return false
    end
  end

  return true
end

function BufRenderer:update_position()
  local path_before = self.path
  local cursor_pos = vim.api.nvim_win_get_cursor(self.last_win)
  local raw_pos = pos_to_raw_pos(cursor_pos, self.lines)
  if not raw_pos then
    return
  end

  self.path = self.element:path_from_pos(raw_pos)

  if not path_equal(path_before, self.path) then
    return true
  end

  return false
end

function BufRenderer:hover(force_update_highlight)
  local path = self.path

  local old_hover_range = self.hover_range

  if not path then
    if self.tooltip ~= nil then
      self.tooltip:close()
      self.tooltip = nil
    end
    vim.api.nvim_buf_clear_namespace(self.buf, self.__hl_ns, 0, -1)
    self.hover_range = nil
    return
  end

  local hover_element, _, hover_element_path = self.element:find_innermost_along(
    path,
    ---@param element Element
    function(element)
      return element.highlightable
    end
  )

  local tt_parent_element, _, tt_parent_element_path = self.element:find_innermost_along(
    path,
    ---@param element Element
    function(element)
      return element.tooltip
    end
  )

  local new_tooltip_element = tt_parent_element and tt_parent_element.tooltip

  if self.tooltip ~= nil and new_tooltip_element == nil then
    self.tooltip:close()
    self.tooltip = nil
  end

  if new_tooltip_element ~= nil then
    local width, height =
      util.make_floating_popup_size(vim.split(new_tooltip_element:to_string(), '\n'))

    local tt_parent_path = tt_parent_element_path
    local bufpos = raw_pos_to_pos(self.element:pos_from_path(tt_parent_path), self.lines)

    if self.tooltip then -- reuse old tooltip window
      -- FIXME: Some method call instead of mutating attributes
      self.tooltip.element = new_tooltip_element
      self.tooltip.parent = self
      self.tooltip.parent_path = tt_parent_element_path
    else
      self.tooltip = new_tooltip_element:renderer {
        buf = util.create_buf {
          listed = false,
          scratch = true,
          options = { bufhidden = 'wipe' },
        },
        keymaps = self.keymaps,
        parent = self,
        parent_path = tt_parent_element_path,
      }
    end

    local win_options = {
      relative = 'win',
      win = self.last_win,
      style = 'minimal',
      width = width,
      height = height,
      border = 'rounded',
      bufpos = bufpos,
      zindex = 50 + self.tooltip.buf, -- later tooltips are guaranteed to have greater buffer handles
    }

    if not self.tooltip:last_win_valid() then
      -- fresh non-reused tooltip, open window
      self.tooltip.last_win = vim.api.nvim_open_win(
        self.tooltip.buf,
        false,  -- avoid firing update_cursor by disabling the autocmds
        vim.tbl_extend('error', win_options, { noautocmd = true } )
      )
      -- workaround for neovim/neovim#13403, as it seems this wasn't entirely resolved by neovim/neovim#14770
      vim.cmd.redraw()
      self.tooltip.last_win_options = vim.deepcopy(win_options)
    elseif not vim.deep_equal(win_options, self.tooltip.last_win_options) then
      vim.api.nvim_win_set_config(self.tooltip.last_win, win_options)
      vim.cmd.redraw()
      self.tooltip.last_win_options = vim.deepcopy(win_options)
    end

    self.tooltip:render()
  end

  if hover_element_path and hover_element then
    local a = self.element:pos_from_path(hover_element_path)
    local start_pos = raw_pos_to_pos(a, self.lines)
    local end_pos = raw_pos_to_pos(a + hover_element._size, self.lines)
    self.hover_range = { start_pos, end_pos }
  else
    self.hover_range = nil
  end

  if force_update_highlight or not vim.deep_equal(old_hover_range, self.hover_range) then
    vim.api.nvim_buf_clear_namespace(self.buf, self.__hl_ns, 0, -1)
    local hlgroup = 'widgetElementHighlight'
    if self.hover_range then
      vim.highlight.range(self.buf, self.__hl_ns, hlgroup, self.hover_range[1], self.hover_range[2])
    end
  end
end

---Fire an event.
---@param event ElementEvent
---@param path? PathNode[]
---@return nil
function BufRenderer:event(event, path, ...)
  local args = { ... }

  path = path or self.path

  if not path then
    return
  end

  if
    not self.element:event(path, event, self:make_event_context(), unpack(args)) and self.parent
  then
    -- bubble up to parent
    return self.parent:event(event, self.parent_path, ...)
  end
end

---@class ElementEventContext
---@field rerender fun():nil
---@field rehover fun():nil
---@field jump_to_last_window fun():nil Jump to the last window the cursor came from.

---@return ElementEventContext
function BufRenderer:make_event_context()
  ---@type ElementEventContext
  return {
    rerender = function()
      self:render()
    end,
    rehover = function()
      self:hover()
    end,
    jump_to_last_window = function()
      if self:last_win_valid() then
        vim.api.nvim_set_current_win(self.last_win)
      end
    end,
  }
end

function BufRenderer:enter_win()
  local deepest_tooltip = self:get_deepest_tooltip()
  if deepest_tooltip:last_win_valid() then
    vim.api.nvim_set_current_win(deepest_tooltip.last_win)
  end
end

function BufRenderer:get_deepest_tooltip()
  ---@diagnostic disable-next-line: need-check-nil
  while self.tooltip do
    self = self.tooltip
  end
  return self
end

---@return BufRenderer
function BufRenderer:get_root_ancestor()
  ---@diagnostic disable-next-line: need-check-nil
  while self.parent do
    self = self.parent
  end
  ---@diagnostic disable-next-line: return-type-mismatch
  return self
end

---@class SelectionOpts<C>
---@field format_item? fun(c: any): string format an item as a string, defaults to tostring
---@field tooltip_for? fun(c: any): string an optional tooltip to show when hovered
---@field start_selected? fun(c: any): boolean whether the item should start initially selected
---@field title? string an optional title, typically used for the prompt
---@field footer? string an optional footer, typically used for instructions
---@field relative_win? number a window ID to open the popup relative to

---Interactively select from a set of choices.
---@generic C : any
---@param choices C[] the set of choices to pick from
---@param opts? SelectionOpts<C>
---@param on_choices fun(chosen: C[], unchosen: C[]): nil a callback called with selected choices
---@return nil
local function select_many(choices, opts, on_choices)
  -- This doesn't exist on `vim.ui` yet. See e.g. neovim/neovim#18161
  -- though the PR is essentially stale/abandoned.
  opts = vim.tbl_extend('keep', opts or {}, {
    format_item = tostring,
    start_selected = function(_) return true end,
    title = 'Select one or more of:',
  })

  local bufnr = vim.api.nvim_create_buf(false, true)
  local win_options = {
    style = 'minimal',
    relative = 'win',
    win = opts.relative_win,
    border = 'rounded',
    title = opts.title,
    footer =  '<Tab>: toggle, <CR>: confirm, <Esc>: cancel',
    footer_pos = 'center',
    bufpos = {100, 10},
    width = 50,
    height = #choices + 2,
    zindex = 50,
  }

  local window = vim.api.nvim_open_win(bufnr, true, win_options)
  vim.wo[window].winfixbuf = true

  local selected = vim.iter(choices):map(opts.start_selected):totable()

  ---Format a choice as text.
  ---@param select boolean whether the choice is selected or not
  ---@param choice any
  ---@return string
  local function totext(select, choice)
    local icon = select and '✅' or '❌'
    return (' %s %s\n'):format(icon, opts.format_item(choice))
  end

  local element = Element:new {
    text = '\n',
    children = vim.iter(ipairs(choices)):map(function(i, choice)
      local self
      self = Element:new {
        text = totext(selected[i], choice),
        events = {
          click = function(ctx)
            -- TODO: This seems like maybe it could/should be a default handler
            --       in our TUI framework for when we have tooltips to show?
            if self.tooltip then
              self:remove_tooltip()
            elseif opts.tooltip_for then
              local tooltip_text = opts.tooltip_for(choice)
              self:add_tooltip(Element.noop(tooltip_text))
            end
            ctx.rehover()
          end,
          toggle = function(ctx)
            selected[i] = not selected[i]
            self.text = totext(selected[i], choice)
            ctx.rerender()
          end,
        },
        keymaps = {
          ['K'] = 'click',
          ['<Tab>'] = 'toggle',
        }
      }
      return self
    end):totable(),

    events = {
      make_selection = function(_)
        vim.api.nvim_win_close(window, true)
        local chosen = {}
        local unchosen = {}
        vim.iter(ipairs(choices)):each(function(i, choice)
          local into = selected[i] and chosen or unchosen
          table.insert(into, choice)
        end)
        on_choices(chosen, unchosen)
      end,
      clear = function(_)
        vim.api.nvim_win_close(window, true)
      end,
    },
  }

  local renderer = element:renderer {
    buf = bufnr,
    keymaps = {
      ['K'] = 'click',
      ['<Tab>'] = 'toggle',
      ['<CR>'] = 'make_selection',
      ['<Esc>'] = 'clear',
    }
  }
  renderer:render()

  -- the 'real' editable region where entries are
  local start_line = 2
  local end_line = #choices + 1
  local first_column = 5

  vim.api.nvim_win_set_cursor(window, { start_line, first_column })

  local group = vim.api.nvim_create_augroup('LeanSelectManyWindow', { clear = false })
  vim.api.nvim_create_autocmd('WinLeave', {
    group = group,
    buffer = bufnr,
    callback = function() renderer:event 'clear' end
  })
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = group,
    buffer = bufnr,
    callback = function()  -- clip the cursor to the real editable region
      local row, column = unpack(vim.api.nvim_win_get_cursor(window))
      row = math.max(math.min(row, end_line), start_line)
      column = math.max(column, first_column)
      vim.api.nvim_win_set_cursor(window, { row, column })
    end,
  })
end

return {
  BufRenderer = BufRenderer,
  Element = Element,
  select_many = select_many,
}
