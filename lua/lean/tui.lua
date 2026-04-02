local async = require 'std.async'

local Buffer = require 'std.nvim.buffer'
local Window = require 'std.nvim.window'

local log = require 'lean.log'

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
---@field hlgroups? string[]|fun():string[]|nil the highlight group(s) for this element's text, or a function that returns them
---@field tooltip? Element? tooltip
---@field highlightable boolean (for buffer rendering) whether to highlight this element when hovering over it
---@field _start_pos? integer[] Computed {line, col} start position (0-indexed), updated during rendering
---@field _end_pos? integer[] Computed {line, col} end position (0-indexed, exclusive), updated during rendering
---@field private __children Element[] this element's children
---@field private __async_init? fun(on_result: fun(Element):nil):nil
local Element = {}
Element.__index = Element

---Renders elements within a specific buffer.
---@class BufRenderer
---@field buffer Buffer Buffer the element renders to
---@field element Element the element rendered by this renderer
---@field width? integer Width of the rendered content.
---@field height? integer Height of the rendered content.
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
---@field hlgroups? string[]|fun():string[]|nil the highlight group(s) for this element's text, or a function that returns them
---@field highlightable boolean? (for buffer rendering) whether to highlight this element when hovering over it
---@field children? Element[] this element's children
---@field private __async_init? fun(on_result: fun(Element):nil):nil

---Create a new Element.
---@param args? ElementNewArgs
---@return Element
function Element:new(args)
  args = args or {}
  local obj = {
    text = args.text or '',
    name = args.name or '',
    hlgroups = args.hlgroups,
    highlightable = args.highlightable or false,
    events = args.events or {},
    __children = args.children or {},
    __async_init = args.__async_init,
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

  local title = self:new { text = opts.title, hlgroups = opts.title_hlgroup and { opts.title_hlgroup } or nil }

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
    vim.validate('opts', opts, 'nil')
    return
  elseif #elements == 1 then
    return opts
      and self:new(vim.tbl_extend('error', opts, { children = { elements[1] } }))
      or elements[1]
  end

  return self:new(
    vim.tbl_extend('error', opts or {}, {
      children = vim.iter(elements):fold(nil, function(acc, k)
        if not acc then return { k } end
        table.insert(acc, Element:new { text = sep })
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
    hlgroups = { 'widgetSelect' },
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
  return Element:new { text = key, hlgroups = { 'widgetKbd' } }
end

---@class ElementLinkArgs
---@field action? fun(ctx: ElementEventContext):boolean? a single action, wired to click
---@field events? EventCallbacks explicit event callbacks (mutually exclusive with action)
---@field text? string the text to show when rendering this element
---@field name? string a named handle for this element, used when path-searching
---@field children? Element[] this element's children

---Create an Element styled as an interactive link.
---
---Use for any element the user can activate (navigate, apply edits, open a
---URL, etc.).  Styling is always enforced — callers specify content and
---behavior, not appearance.
---
---Provide either `action` (wired to click) or `events` (explicit map), not both.
---@param args ElementLinkArgs
---@return Element
function Element.link(args)
  vim.validate('action', args.action, 'function', true)
  vim.validate('events', args.events, 'table', true)
  if args.action and args.events then
    error('Element.link: provide action or events, not both', 2)
  end
  if not args.action and not args.events then
    error('Element.link: one of action or events is required', 2)
  end
  return Element:new {
    text = args.text,
    name = args.name,
    children = args.children,
    events = args.events or { click = args.action },
    highlightable = true,
    hlgroups = { 'widgetLink' },
  }
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

---Create an Element whose contents will be resolved asynchronously.
---@param name? string the name of the element, used for debugging
---@return Element element the (empty) element, placeable within other elements
---@return fun(Element):nil on_result a callback to call when the element is resolved
function Element.async(name)
  local element, resolve

  ---Replaced if we successfully resolve the element, otherwise logs an error.
  resolve = function(_)
    log:error {
      message = 'Element.async was not resolved',
      name = name,
    }
  end
  element = Element:new {
    name = name,
    __async_init = function(on_result)
      resolve = on_result
    end,
  }

  return element, function(resolved_element)
    resolve(resolved_element)
  end
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

---Render the element into a string.
---@return string
function Element:to_string()
  return table.concat(self:render_lines().lines, '\n')
end

---Render the element into lines, highlights, and dimensions in a single pass.
---@param renderer? BufRenderer
---@return { lines: string[], highlights: { hlgroup: string, start_pos: integer[], end_pos: integer[] }[], width: integer, height: integer }
function Element:render_lines(renderer)
  log:trace { message = 'rendering element to lines', name = self.name }
  local lines = { '' }
  local highlights = {}
  local line_idx = 1
  local col = 0
  local width = 0

  ---@param element Element
  local function go(element)
    if element.__async_init and renderer then
      renderer.pending_elements[element] = true
      element.__async_init(function(resolved_element) ---@type Element resolved_element
        element:set_children { resolved_element }
        renderer.pending_elements[element] = nil
        renderer:render()
      end)
      element.__async_init = nil -- only run once
    end

    element._start_pos = { line_idx - 1, col }

    local text = element.text
    if text ~= '' then
      local pos = 1
      while pos <= #text do
        local nl = text:find('\n', pos, true)
        if nl then
          local chunk = text:sub(pos, nl - 1)
          lines[line_idx] = lines[line_idx] .. chunk
          width = math.max(width, vim.fn.strdisplaywidth(lines[line_idx]))
          line_idx = line_idx + 1
          lines[line_idx] = ''
          col = 0
          pos = nl + 1
        else
          local rest = text:sub(pos)
          lines[line_idx] = lines[line_idx] .. rest
          col = col + #rest
          break
        end
      end
    end

    for _, child in ipairs(element.__children) do
      go(child)
    end

    element._end_pos = { line_idx - 1, col }

    local hlgroups = element.hlgroups
    if type(hlgroups) == 'function' then
      hlgroups = hlgroups(element)
    end
    if hlgroups then
      for _, hg in ipairs(hlgroups) do
        table.insert(highlights, { hlgroup = hg, start_pos = element._start_pos, end_pos = element._end_pos })
      end
    end
  end

  go(self)
  width = math.max(width, vim.fn.strdisplaywidth(lines[line_idx]))

  return { lines = lines, highlights = highlights, width = width, height = line_idx }
end

---Represents a node in a path through an element.
---@class PathNode
---@field idx number the index in the current element's children to follow
---@field name string the name that the indexed child should have
---@field position? integer[] if provided, the (0-indexed) {line, col} cursor position within this element

---Is position a strictly before position b? (both 0-indexed {line, col})
local function pos_before(a, b)
  return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
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

---Get the (0-indexed) {line, col} position of the element arrived at by following the given path.
---@param path PathNode[] the path to follow
---@return integer[]? the {line, col} position if the path was valid, nil otherwise
function Element:pos_from_path(path)
  local _, element = self:div_from_path(path)
  if not element or element._start_pos == nil then
    return nil
  end

  -- Use the stored cursor position if it's still within the element's range.
  local position = path[#path].position
  if position
    and not pos_before(position, element._start_pos)
    and pos_before(position, element._end_pos)
  then
    return position
  end

  return element._start_pos
end

---Find the innermost element along a path satisfying a predicate.
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

---Iterate over this element's direct children.
---@return Iter iterator yielding child elements (use :enumerate() for indices)
function Element:children()
  return vim.iter(self.__children)
end

---Get the path at the given (0-indexed) {line, col} position.
---(requires _start_pos/_end_pos to have been computed, e.g. via to_string or render_lines)
---@param pos integer[] {line, col} position (0-indexed)
---@return PathNode[]? the path at this position
---@return Element[]? the stack of elements along this path
function Element:path_from_pos(pos)
  local path = { { idx = 0, name = self.name } }
  local stack = { self }

  ::next::
  if self._end_pos == nil then
    return nil
  end

  -- Where does this element's own text end (i.e. where do children begin)?
  local text_end = self.__children[1] and self.__children[1]._start_pos or self._end_pos

  -- Is pos within this element's own text?
  if pos_before(pos, text_end) then
    path[#path].position = pos
    return path, stack
  end

  -- Find which child contains pos.
  for idx, child in ipairs(self.__children) do
    if child._end_pos == nil then
      return nil
    end
    if pos_before(pos, child._end_pos) then
      table.insert(path, { idx = idx, name = child.name })
      table.insert(stack, child)
      self = child
      goto next
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

  async.run(function()
    return event_element.events[event](unpack(args))
  end)
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

---Convert an ElementEvent name to its `<Plug>` name.
---
---E.g. `'go_to_def'` → `'<Plug>(LeanInfoviewGoToDef)'`.
---@param event ElementEvent
---@return string
local function event_plug_name(event)
  local pascal = event
    :gsub('(%a)([^_]*)', function(a, b) return a:upper() .. b end)
    :gsub('_', '')
  return ('<Plug>(LeanInfoview%s)'):format(pascal)
end

---Create a new BufRenderer.
function BufRenderer:new(obj)
  obj = obj or {}
  obj.pending_elements = {}
  local new_renderer = setmetatable(obj, self)
  obj.buffer.o.modifiable = false

  obj.buffer:create_autocmd({ 'BufEnter', 'CursorMoved' }, {
    group = vim.api.nvim_create_augroup('WidgetPosition', { clear = false }),
    callback = function()
      new_renderer:update_cursor()
    end,
  })

  local buf = obj.buffer

  -- Note that only closures work here, we can't go storing this on vim.b due
  -- to neovim/neovim#12544 wherein the metatable would be lost on retrieval.
  -- In other words, if we do vim.b[..].foo = new_renderer, when we come back
  -- to look at it, it's not a BufRenderer anymore. Surprise!
  --
  -- We define buffer-local <Plug> mappings alongside the default keys so that
  -- any of them can be used as a remapping destination.
  buf.keymaps:set('n', '<Plug>(LeanInfoviewEnterTooltip)', function()
    new_renderer:enter_tooltip()
  end, { desc = 'Enter a tooltip.' })
  buf.keymaps:set('n', '<Plug>(LeanInfoviewParentTooltip)', function()
    new_renderer:goto_parent_tooltip()
  end, { desc = 'Go to the "parent" tooltip.' })
  buf.keymaps:set(
    'n',
    '<Plug>(LeanAbbreviationsReverseLookup)',
    require'lean.abbreviations'.show_reverse_lookup,
    { desc = 'Show how to type the unicode character under the cursor.' }
  )

  -- Register a <Plug> for every public ElementEvent so any of them can be
  -- rebound to a different key.
  local element_events = {
    'click',
    'select',
    'clear',
    'clear_all',
    'goto_last_window',
    'go_to_def',
    'go_to_decl',
    'go_to_type',
  }
  local element_event_set = {}
  for _, event in ipairs(element_events) do
    buf.keymaps:set('n', event_plug_name(event), function()
      new_renderer:event(event)
    end, { desc = ('Fire a %s event.'):format(event) })
    element_event_set[event] = true
  end

  buf.keymaps:set(
    'n',
    '<Tab>',
    '<Plug>(LeanInfoviewEnterTooltip)',
    { remap = true, desc = 'Enter a tooltip.' }
  )
  buf.keymaps:set(
    'n',
    'J',
    '<Plug>(LeanInfoviewEnterTooltip)',
    { remap = true, desc = 'Enter a tooltip.' }
  )
  buf.keymaps:set(
    'n',
    '<S-Tab>',
    '<Plug>(LeanInfoviewParentTooltip)',
    { remap = true, desc = 'Go to the "parent" tooltip.' }
  )
  buf.keymaps:set(
    'n',
    '<LocalLeader>\\',
    '<Plug>(LeanAbbreviationsReverseLookup)',
    { remap = true, desc = 'Show how to type the unicode character under the cursor.' }
  )

  for key, event in pairs(obj.keymaps or {}) do
    local rhs = element_event_set[event] and event_plug_name(event) or function()
      new_renderer:event(event)
    end
    buf.keymaps:set('n', key, rhs,
      { remap = element_event_set[event], desc = ('Fire a %s event.'):format(event) })
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
  log:trace { message = 'rendering buffer', bufnr = self.buffer.bufnr }
  if not self.buffer:is_loaded() then
    log:warning {
      message = 'rendering an unloaded buffer',
      bufnr = self.buffer.bufnr,
    }
    return
  end

  self.buffer:clear_namespace(self.__tui_ns)

  local result = self.element:render_lines(self)
  self.width = result.width
  self.height = result.height

  self.buffer.o.modifiable = true
  -- XXX: Again I do not understand why tests occasionally are flaky,
  --      complaining about invalid buffer names, if we don't have this pcall.
  local ok, err = pcall(Buffer.set_lines, self.buffer, result.lines)
  if not ok then
    log:error {
      message = 'infoview failed to update',
      bufnr = self.buffer.bufnr,
      error = err,
    }
  end
  self.buffer.o.modifiable = false

  for _, hl in ipairs(result.highlights) do
    vim.hl.range(self.buffer.bufnr, self.__tui_ns, hl.hlgroup, hl.start_pos, hl.end_pos)
  end

  if self.path then
    -- on a rerender any previously existing paths may be invalid
    local _, leaf = self.element:div_from_path(self.path)
    if not leaf then
      self.path = nil
    elseif self:last_window_valid() and leaf._start_pos then
      local position = self.path[#self.path].position
      local pos = (position
        and not pos_before(position, leaf._start_pos)
        and pos_before(position, leaf._end_pos))
        and position
        or leaf._start_pos
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
  local new_path = self.element:path_from_pos { cursor_pos[1] - 1, cursor_pos[2] }
  if new_path then
    self.path = new_path

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
    self.buffer:clear_namespace(self.__hl_ns)
    self.hover_range = nil
    return
  end

  local stack = self.element:div_from_path(path)
  if not stack then
    return
  end

  -- Find innermost highlightable and tooltip-bearing elements in one pass.
  local hover_element, tt_parent_element
  local tt_parent_element_path
  for i = #stack, 1, -1 do
    if not hover_element and stack[i].highlightable then
      hover_element = stack[i]
    end
    if not tt_parent_element and stack[i].tooltip then
      tt_parent_element = stack[i]
      tt_parent_element_path = vim.list_slice(path, 1, i)
    end
    if hover_element and tt_parent_element then
      break
    end
  end

  local new_tooltip_element = tt_parent_element and tt_parent_element.tooltip

  if self.tooltip ~= nil and new_tooltip_element == nil then
    self.tooltip:close()
    self.tooltip = nil
  end

  if new_tooltip_element ~= nil then
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

    self.tooltip:render()

    if not self.tooltip:last_window_valid() then
      self.tooltip.last_window = self.last_window:float {
        buffer = self.tooltip.buffer,
        enter = false,
        noautocmd = true,  -- avoid firing update_cursor by disabling the autocmds
        style = 'minimal',
        width = self.tooltip.width,
        height = self.tooltip.height,
        border = 'rounded',
        bufpos = tt_parent_element._start_pos,
        zindex = 50 + self.tooltip.buffer.bufnr, -- later tooltips are guaranteed to have greater buffer handles
      }
    end
  end

  if hover_element then
    self.hover_range = { hover_element._start_pos, hover_element._end_pos }
  else
    self.hover_range = nil
  end

  if force_update_highlight or not vim.deep_equal(old_hover_range, self.hover_range) then
    self.buffer:clear_namespace(self.__hl_ns)
    local hlgroup = 'widgetElementHighlight'
    if self.hover_range then
      vim.hl.range(self.buffer.bufnr, self.__hl_ns, hlgroup, self.hover_range[1], self.hover_range[2])
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

---Convert an element path to a (1,0)-indexed buffer position.
---@param path PathNode[]
---@return {[1]: integer, [2]: integer}? pos 1-indexed line, 0-indexed column
function BufRenderer:buf_position_from_path(path)
  local pos = self.element:pos_from_path(path)
  if pos then
    return { pos[1] + 1, pos[2] }
  end
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
