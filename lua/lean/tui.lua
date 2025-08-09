local async = require 'plenary.async'

local Buffer = require 'std.nvim.buffer'
local Window = require 'std.nvim.window'

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
---| '"click"'     # Click on the element.
---| '"select"'    # Select or unselect ("shift+click") an element
---
---| '"clear"'     # Clear the element.
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
---@field hlgroup? string|fun(string):string? the highlight group for this element's text, or a function that returns it
---@field tooltip? Element? tooltip
---@field highlightable boolean (for buffer rendering) whether to highlight this element when hovering over it
---@field _size? integer Computed size of this element, updated by `Element:to_string`
---@field private __children Element[] this element's children
local Element = {}
Element.__index = Element

---Renders elements within a specific buffer.
---@class BufRenderer
---@field buffer Buffer Buffer the element renders to
---@field element Element the element rendered by this renderer
---@field lines? string[] Rendered lines.
---@field path? PathNode[] Current cursor path
---@field last_window? Window window of the last event
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
---@field hlgroup? string|fun():string? the highlight group for this element's text, or a function that returns it
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

---@class TitledElementArgs
---@field title string
---@field margin? integer how many newlines separating the title from body (defaulting to 2)
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

  local sep = self:new { text = string.rep('\n', opts.margin or 2) }
  return self:new { children = { title, sep, body } }
end

---Create an element which joins a list-like table of elements with the provided separator.
---@param elements Element[]
---@param sep string
---@param opts ElementNewArgs?
---@return Element?
function Element:concat(elements, sep, opts)
  if #elements == 0 then
    -- sigh, polyfill nonsense
    if vim.version.lt(vim.version(), { 0, 11, 0 }) then
      vim.validate { opts = { opts, 'nil' } }
    else
      vim.validate('opts', opts, 'nil')
    end
    return
  elseif #elements == 1 then
    return opts
      and self:new(vim.tbl_extend('error', opts, { children = { elements[1] } }))
      or elements[1]
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

---@generic T
---@class SelectionOpts<T>
---@field prompt string? the prompt to show when selecting a choice
---@field initial string the initial text to show
---@field format_item fun(T):string render the item to a string

---Create an element which represents a selectable choice.
---
---Parallels the HTML `<select>` tag.
---@generic T
---@param choices T[]
---@param opts? SelectionOpts<T>
---@param on_choice? fun(T):nil callback for when the choice is known
---@return Element
function Element.select(choices, opts, on_choice)
  if not on_choice then
    on_choice = function(choice)
      return Element:new { text = choice }
    end
  end
  opts = vim.tbl_extend('keep', opts or {}, {
    initial = choices[1],
    format_item = tostring,
  })

  local selected = Element:new {}
  local function update_selected(choice)
    selected:set_children { Element:new { text = opts.format_item(choice) } }
  end
  update_selected(opts.initial)

  return Element:new {
    children = {
      selected,
      Element:new { text =  ' ▾' },
    },
    highlightable = true,
    hlgroup = 'widgetSelect',
    events = {
      click = function(ctx)
        vim.ui.select(choices, {
          format_item = opts.format_item,
          prompt = opts.prompt,
        }, function(choice)
          if not choice then
            return
          end
          on_choice(choice)
          update_selected(choice)
          ctx:rerender()
        end)
      end,
    },
  }
end

---Create an element which represents textual user input.
---
---Parallels the HTML `<kbd>` tag.
---@param key string
---@return Element
function Element.kbd(key)
  return Element:new { text = key, hlgroup = 'widgetKbd' }
end

---Create an Element whose click event does nothing.
---@param text? string the text to show when rendering this element
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

---Find the innermost element satisfying a predicate.
---@param path PathNode[]
---@param check fun(_, element:Element):any
---@return Element found The element satisfying check
---@return Element[] stack The element stack up to and including that element
---@return PathNode[] subpath The subpath up to that element
---@overload fun(path: PathNode[], check):nil if no element is found
function Element:find_innermost_along(path, check)
  local stack, _ = self:div_from_path(path)
  if stack == nil then
    return
  end

  local i, element = vim.iter(stack):enumerate():rfind(check)
  if i then
    return element, vim.list_slice(stack, 1, i), vim.list_slice(path, 1, i)
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
  local event_element = self:find_innermost_along(path, function(_, element)
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

---Walk all elements in this element.
---
---Visits the element itself first, then all children in order, then a tooltip
---if present.
---@return fun():Element iterator
---@return any state
---@return any ctrl
function Element:walk()
  local stack = { self }
  local function iter()
    local e = table.remove(stack)
    if not e then
      return nil
    end

    if e.tooltip then
      table.insert(stack, e.tooltip)
    end

    for i = #e.__children, 1, -1 do -- reverse so they're iterated in original order
      table.insert(stack, e.__children[i])
    end
    return e
  end
  return iter, nil, nil
end

---Returns the first element matching the given predicate.
---@param check fun(element:Element):boolean?
function Element:find(check)
  return vim.iter(self:walk()):find(check)
end

---Return all elements matching the given predicate.
---@param check fun(element:Element):boolean?
function Element:filter(check)
  return vim.iter(self:walk()):filter(check)
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
  obj.buffer.o.modifiable = false

  obj.buffer:create_autocmd({ 'BufEnter', 'CursorMoved' }, {
    group = vim.api.nvim_create_augroup('WidgetPosition', { clear = false }),
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
  end, { buffer = obj.buffer.bufnr, desc = 'Enter a tooltip.' })
  vim.keymap.set('n', 'J', function()
    new_renderer:enter_tooltip()
  end, { buffer = obj.buffer.bufnr, desc = 'Enter a tooltip.' })
  vim.keymap.set('n', '<S-Tab>', function()
    new_renderer:goto_parent_tooltip()
  end, { buffer = obj.buffer.bufnr, desc = 'Go to the "parent" tooltip.' })
  vim.keymap.set(
    'n',
    '<LocalLeader>\\',
    require'lean.abbreviations'.show_reverse_lookup,
    { buffer = obj.buffer.bufnr, desc = 'Show how to type the unicode character under the cursor.' }
  )

  for key, event in pairs(obj.keymaps or {}) do
    vim.keymap.set('n', key, function()
      new_renderer:event(event)
    end, { buffer = obj.buffer.bufnr, desc = ('Fire a %s event.'):format(event) })
  end

  return new_renderer
end

function BufRenderer:close()
  if self.buffer:is_loaded() then
    self.buffer:force_delete()
  end
  if self.tooltip then
    self.tooltip.parent = nil
    self.tooltip.parent_path = nil
    self.tooltip:close()
    self.tooltip = nil
  end
end

function BufRenderer:render()
  local buf = self.buffer.bufnr
  if not self.buffer:is_loaded() then
    log:warning { message = 'rendering an unloaded buffer', buf = buf }
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, self.__tui_ns, 0, -1)

  local text = self.element:to_string()
  local lines = vim.split(text, '\n')
  self.lines = lines

  self.buffer.o.modifiable = true
  -- XXX: Again I do not understand why tests occasionally are flaky,
  --      complaining about invalid buffer names, if we don't have this pcall.
  local ok, _ = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
  if not ok then
    log:error { message = 'infoview failed to update', buf = buf }
  end
  self.buffer.o.modifiable = false

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
    elseif self:last_window_valid() then
      local raw_pos, offset = self.element:pos_from_path(self.path)
      local pos = raw_pos_to_pos(raw_pos + offset, lines)
      self.last_window:set_cursor { pos[1] + 1, pos[2] }
    end
  end

  self:hover(true)
end

function BufRenderer:enter_tooltip()
  if self.tooltip and self.tooltip:last_window_valid() then
    self.tooltip.last_window:make_current()
  end
end

function BufRenderer:goto_parent_tooltip()
  if self.parent and self.parent:last_window_valid() then
    self.parent.last_window:make_current()
  end
end

function BufRenderer:last_window_valid()
  return self.last_window
    and self.last_window:is_valid()
    and self.last_window:bufnr() == self.buffer.bufnr
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

---@param window Window?
function BufRenderer:update_cursor(window)
  window = window or Window:current()
  if window:bufnr() == self.buffer.bufnr then
    self.last_window = window
  end
  if not self:last_window_valid() then
    return
  end

  local path_before = self.path
  local cursor_pos = self.last_window:cursor()
  local raw_pos = pos_to_raw_pos(cursor_pos, self.lines)
  if raw_pos then
    self.path = self.element:path_from_pos(raw_pos)

    if not path_equal(path_before, self.path) then
      self:hover()
    end
  end
end

function BufRenderer:hover(force_update_highlight)
  local path = self.path

  local old_hover_range = self.hover_range

  if not path then
    if self.tooltip ~= nil then
      self.tooltip:close()
      self.tooltip = nil
    end
    vim.api.nvim_buf_clear_namespace(self.buffer.bufnr, self.__hl_ns, 0, -1)
    self.hover_range = nil
    return
  end

  local hover_element, _, hover_element_path = self.element:find_innermost_along(
    path,
    ---@param element Element
    function(_, element)
      return element.highlightable
    end
  )

  local tt_parent_element, _, tt_parent_element_path = self.element:find_innermost_along(
    path,
    ---@param element Element
    function(_, element)
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
        buffer = Buffer.create {
          listed = false,
          scratch = true,
          options = { bufhidden = 'wipe' },
        },
        keymaps = self.keymaps,
        parent = self,
        parent_path = tt_parent_element_path,
      }
    end

    if not self.tooltip:last_window_valid() then
      self.tooltip.last_window = self.last_window:float {
        buffer = self.tooltip.buffer,
        enter = false,
        noautocmd = true,  -- avoid firing update_cursor by disabling the autocmds
        style = 'minimal',
        width = width,
        height = height,
        border = 'rounded',
        bufpos = bufpos,
        zindex = 50 + self.tooltip.buffer.bufnr, -- later tooltips are guaranteed to have greater buffer handles
      }
      -- workaround for neovim/neovim#13403, as it seems this wasn't entirely resolved by neovim/neovim#14770
      vim.cmd.redraw()
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
    vim.api.nvim_buf_clear_namespace(self.buffer.bufnr, self.__hl_ns, 0, -1)
    local hlgroup = 'widgetElementHighlight'
    if self.hover_range then
      vim.highlight.range(self.buffer.bufnr, self.__hl_ns, hlgroup, self.hover_range[1], self.hover_range[2])
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
      if self:last_window_valid() then
        self.last_window:make_current()
      end
    end,
  }
end

function BufRenderer:enter_win()
  local deepest = self
  while deepest.tooltip do
    deepest = deepest.tooltip
  end
  if deepest:last_window_valid() then
    deepest.last_window:make_current()
  end
end

---@class SelectionOpts<C>
---@field format_item? fun(c: any): string format an item as a string, defaults to tostring
---@field tooltip_for? fun(c: any): string an optional tooltip to show when hovered
---@field start_selected? fun(c: any): boolean whether the item should start initially selected
---@field title? string an optional title, typically used for the prompt
---@field footer? string an optional footer, typically used for instructions
---@field relative_window? Window a window to open the popup relative to

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

  local buffer = Buffer.create { listed = false, scratch = true }
  local relative = opts.relative_window or Window:current()
  local modal = relative:float {
    buffer = buffer,
    enter = true,
    style = 'minimal',
    border = 'rounded',
    title = opts.title,
    footer =  '<Tab>: toggle, <CR>: confirm, <Esc>: cancel',
    footer_pos = 'center',
    bufpos = { 100, 10 },
    width = 50,
    height = #choices + 2,
    zindex = 50,
  }
  modal.o.winfixbuf = true

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
        modal:force_close()
        local chosen = {}
        local unchosen = {}
        vim.iter(ipairs(choices)):each(function(i, choice)
          local into = selected[i] and chosen or unchosen
          table.insert(into, choice)
        end)
        on_choices(chosen, unchosen)
      end,
      clear = function(_)
        modal:force_close()
      end,
    },
  }

  local renderer = element:renderer {
    buffer = buffer,
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

  modal:set_cursor { start_line, first_column }

  local group = vim.api.nvim_create_augroup('LeanSelectManyWindow', { clear = false })
  buffer:create_autocmd('WinLeave', {
    group = group,
    callback = function() renderer:event 'clear' end
  })
  buffer:create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = group,
    callback = function()  -- clip the cursor to the real editable region
      local row, column = unpack(modal:cursor())
      row = math.max(math.min(row, end_line), start_line)
      column = math.max(column, first_column)
      modal:set_cursor { row, column }
    end,
  })
end

return {
  BufRenderer = BufRenderer,
  Element = Element,
  select_many = select_many,
}
