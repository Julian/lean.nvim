local async = require 'std.async'

local Buffer = require 'std.nvim.buffer'
local Window = require 'std.nvim.window'

local log = require 'lean.log'

local OverlayState -- defined after BufRenderer

---A fire-able event whose behavior is `Element`-specific.
---
---An element can define how to handle the event, as well as which keyboard
---keys (or mouse buttons) trigger it.
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
---| '"select"'    # Select or unselect (ctrl+click) an element
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
---@field hlgroups? string[]|fun():string[]|nil highlight group(s) or a function returning them
---@field tooltip? Element? tooltip
---@field tooltip_id? string stable identity for this element's interactive tooltip (a server `GoalsLocation` when available), preferred over its path as a store key
---@field url? string a URI to associate with this element; rendered as an OSC 8 terminal hyperlink over its range (see `Element.link`)
---@field highlightable boolean (for buffer rendering) highlight this element when hovering
---@field is_block boolean block-level element — starts on a new line when following content
---@field margin integer extra blank lines above and below this block (CSS-like margin; collapses with adjacent margins)
---@field line_prefix? LinePrefixSpec text prepended to every line within this element
---@field private __children Element[] this element's children
---@field private __async_init? fun(on_result: fun(Element):nil):nil
---@field private __foldable? Foldable only set on containers returned by `:foldable`
---@field __state? ElementStateHandle opt-in handle for carrying user-toggled state across rebuilds
local Element = {}
Element.__index = Element

---A CSS `justify-content` value, accepted in full though several collapse to the
---same behaviour for our single flex item (see `BufRenderer.justify_content`).
---@alias JustifyContent 'start'|'center'|'end'|'flex-start'|'flex-end'|'space-between'|'space-around'|'space-evenly'

---Renders elements within a specific buffer.
---@class BufRenderer
---@field buffer Buffer Buffer the element renders to
---@field element Element the element rendered by this renderer
---@field width? integer Width of the rendered content.
---@field height? integer Height of the rendered content.
---@field positions? table<Element, { start_pos: integer[], end_pos: integer[] }> Element position map.
---@field path? PathNode[] Current cursor path
---@field last_window? Window window of the last event
---@field keymaps table Extra keymaps (inherited by tooltips)
---@field hover_range? integer[][] (0,0)-range of the highlighted node
---@field tooltip? BufRenderer currently open tooltip
---@field tooltips table<string, Element> open interactive tooltip contents, keyed by `path_key`
---@field parent? BufRenderer Parent renderer
---@field parent_path? PathNode[] Path in parent element, events bubble up to the parent there
---@field justify_content? JustifyContent CSS `justify-content` along the block (vertical) axis, treating the window as a column flex container holding this content as its single item; defaults to 'start'
local BufRenderer = {
  __tui_ns = vim.api.nvim_create_namespace 'lean.tui',
  __hl_ns = vim.api.nvim_create_namespace 'lean.highlights',
}
BufRenderer.__index = BufRenderer

---@class LinePrefixSpec
---@field text string prefix text prepended to every line within this element
---@field hlgroup? string highlight group for the prefix text

---@class ElementNewArgs
---@field events? EventCallbacks event function map
---@field text? string the text to show when rendering this element
---@field name? string a named handle for this element, used when path-searching
---@field hlgroups? string[]|fun():string[]|nil highlight group(s) or a function returning them
---@field highlightable boolean? (for buffer rendering) highlight this element when hovering
---@field children? Element[] this element's children
---@field url? string a URI to associate with this element, rendered as an OSC 8 terminal hyperlink
---@field is_block? boolean block-level element — starts on a new line when following content
---@field margin? integer extra blank lines above and below this block (CSS-like margin; collapses with adjacent margins)
---@field line_prefix? LinePrefixSpec text prepended to every line within this element
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
    url = args.url,
    highlightable = args.highlightable or false,
    events = args.events or {},
    __children = args.children or {},
    __async_init = args.__async_init,
    overlay = args.overlay,
    is_block = args.is_block or false,
    margin = args.margin or 0,
    line_prefix = args.line_prefix,
  }
  return setmetatable(obj, self)
end

---@class TitledElementArgs
---@field title? Element the title element
---@field gap? integer how many newlines separating the title from body (defaulting to 2)
---@field body Element[]?

---Create an element with a title and optional body contents.
---@param opts TitledElementArgs
---@return Element?
function Element:titled(opts)
  local body_elements = opts.body
  local has_body = body_elements and #body_elements > 0

  if not opts.title then
    return has_body and self:new { children = body_elements } or nil
  end

  if not has_body then
    return opts.title
  end

  local sep = self:new { text = string.rep('\n', opts.gap or 2) }
  return self:new {
    children = {
      opts.title,
      sep,
      self:new { children = body_elements },
    },
  }
end

---@class FoldableElementArgs: TitledElementArgs
---@field open? boolean whether initially open (defaults to true)
---@field on_open? fun(body: Element):nil called with the body element each time the section opens
---@field events? EventCallbacks extra events fired on the whole title row (alongside the built-in click-to-toggle)
---@field before_arrow? Element rendered before the toggle arrow, but still inside the clickable title row (e.g. tree indentation)

---A handle attached to a foldable container, exposing its open state and
---body so they can be inspected or synced from outside (e.g. when a tree
---rebuild needs to carry user-toggled state forward).
---@class Foldable
---@field open boolean current open state
---@field body Element body element, stable across open/closed layouts
---@field set_open fun(self: Foldable, open: boolean): nil

---Create a foldable element with a title and optional body contents.
---
---Wraps `titled` with a toggle arrow (▼/▶) and click-to-collapse behavior.
---@param opts FoldableElementArgs
---@return Element
function Element:foldable(opts)
  local body_elements = opts.body
  local has_body = body_elements and #body_elements > 0

  if not has_body and not opts.on_open then
    return opts.title
  end

  local on_open = opts.on_open or function() end
  local on_close = opts.on_close or function() end
  local initially_open = opts.open ~= false
  local arrow = self:new { text = initially_open and '▼ ' or '▶ ' }
  local body = self:new { children = body_elements }

  -- `container` and `layout` are forward-declared so the foldable handle
  -- can close over them; their values are assigned below before the handle
  -- is ever exercised.
  local container
  local layout

  ---@type Foldable
  local foldable = {
    open = initially_open,
    body = body,
    set_open = function(handle, new_open)
      if handle.open == new_open then
        return
      end
      handle.open = new_open
      arrow.text = new_open and '▼ ' or '▶ '
      if new_open then
        on_open(handle.body)
      else
        on_close()
      end
      container:set_children { layout(new_open) }
    end,
  }

  local title_row_children = {}
  if opts.before_arrow then
    table.insert(title_row_children, opts.before_arrow)
  end
  table.insert(title_row_children, arrow)
  table.insert(title_row_children, opts.title)
  local title_row = self:new {
    children = title_row_children,
    highlightable = true,
    events = vim.tbl_extend('error', opts.events or {}, {
      click = function(ctx)
        foldable:set_open(not foldable.open)
        ctx.rerender()
      end,
    }),
  }

  layout = function(open)
    if open then
      return self:titled { title = title_row, body = { body }, gap = opts.gap }
    end
    return title_row
  end

  container = self:new { children = { layout(initially_open) } }
  container.__foldable = foldable
  container.__state = {
    snapshot = function()
      return foldable.open
    end,
    restore = function(_, saved)
      foldable:set_open(saved)
    end,
    walk = function()
      return foldable.body
    end,
  }

  return container
end

---@class ElementStateHandle
---@field snapshot fun(self): any captures the current user-toggled state
---@field restore fun(self, saved: any): nil reapplies a previously-captured value
---@field walk? fun(self): Element optional override for state-transfer traversal.
---       Returned element is recursed into in place of the host element's
---       `__children`. Use when the host's children are state-dependent
---       (e.g. a foldable's children change with `open`) so the transfer can
---       still find a stable subtree.

---Walk two parallel element trees and copy user-toggled state from `from`
---onto `onto`, so a rebuild doesn't snap user toggles back to defaults.
---
---Widgets opt in by attaching a `__state` handle (an `ElementStateHandle`) to
---the element whose state they own. Foldables register one of these in
---`Element:foldable`, so foldable open state is preserved automatically.
---@param from Element source element tree (e.g. the previous data element)
---@param onto Element destination element tree (e.g. the freshly-built one)
function Element.transfer_state(from, onto)
  if from.__state and onto.__state then
    onto.__state:restore(from.__state:snapshot())
  end
  -- If the handle declares a `walk`, the element's own `__children` are
  -- state-dependent and must be skipped in favour of the walked subtree.
  if from.__state and from.__state.walk then
    if onto.__state and onto.__state.walk then
      Element.transfer_state(from.__state:walk(), onto.__state:walk())
    end
    return
  end
  for i, child in ipairs(from.__children) do
    local other = onto.__children[i]
    if not other then
      return
    end
    Element.transfer_state(child, other)
  end
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
    return opts and self:new(vim.tbl_extend('error', opts, { children = { elements[1] } }))
      or elements[1]
  end

  return self:new(vim.tbl_extend('error', opts or {}, {
    children = vim.iter(elements):fold(nil, function(acc, k)
      if not acc then
        return { k }
      end
      table.insert(acc, Element:new { text = sep })
      table.insert(acc, k)
      return acc
    end),
  }))
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
      Element:new { text = ' ▾' },
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

---Create a title element with a highlight group.
---@param text string
---@param hlgroup? string the highlight group (defaults to 'Title')
---@return Element
function Element.title(text, hlgroup)
  return Element:new { text = text, hlgroups = { hlgroup or 'Title' } }
end

---@class ElementLinkArgs
---@field action? fun(ctx: ElementEventContext):boolean? a single action, wired to click
---@field events? EventCallbacks explicit event callbacks (mutually exclusive with action)
---@field url? string a URI this link points at (see below)
---@field text? string the text to show when rendering this element
---@field name? string a named handle for this element, used when path-searching
---@field children? Element[] this element's children

---Create an Element styled as an interactive link.
---
---Use for any element the user can activate (navigate, apply edits, open a
---URL, etc.).  Styling is always enforced — callers specify content and
---behavior, not appearance.
---
---The in-editor activation is one of, in order of precedence: `events` (an
---explicit map, e.g. `go_to_def`), `action` (wired to click), or — when neither
---is given — opening `url` via `vim.ui.open`.  `action` and `events` are
---mutually exclusive; at least one of the three is required.
---
---`url` is orthogonal to the activation: independently of what clicking does, it
---is rendered as an OSC 8 terminal hyperlink over the link (so supporting
---terminals make it natively clickable) and, unless the element already has a
---tooltip, revealed as one. So a link can run a rich in-editor action *and*
---expose a URL to the terminal.
---@param args ElementLinkArgs
---@return Element
function Element.link(args)
  vim.validate('action', args.action, 'function', true)
  vim.validate('events', args.events, 'table', true)
  vim.validate('url', args.url, 'string', true)
  if args.action and args.events then
    error('Element.link: provide action or events, not both', 2)
  end
  if not (args.action or args.events or args.url) then
    error('Element.link: one of action, events, or url is required', 2)
  end
  local events = args.events
  if not events then
    local action = args.action or function()
      vim.ui.open(args.url)
    end
    events = { click = action }
  end
  local element = Element:new {
    text = args.text,
    name = args.name,
    children = args.children,
    events = events,
    url = args.url,
    highlightable = true,
    hlgroups = { 'widgetLink' },
  }
  if args.url then
    element:add_tooltip(Element:new { text = args.url })
  end
  return element
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

---@alias PositionMap table<Element, { start_pos: integer[], end_pos: integer[] }>

---Render the element into lines, highlights, and dimensions in a single pass.
---@param renderer? BufRenderer
---@return { lines: string[], highlights: { hlgroup: string, start_pos: integer[], end_pos: integer[] }[], urls: { url: string, start_pos: integer[], end_pos: integer[] }[], width: integer, height: integer, positions: PositionMap }
function Element:render_lines(renderer)
  log:trace { message = 'rendering element to lines', name = self.name }
  local lines = { '' }
  local highlights = {}
  local urls = {}
  local positions = {} ---@type PositionMap
  local line_idx = 1
  local col = 0
  local width = 0

  -- Tracks whether the current line has any non-prefix content.
  -- Block elements only force a new line when there is actual content
  -- on the current line, implementing CSS-like margin collapsing.
  local has_content = false

  -- Number of newlines pending before the next non-empty content.  Set when
  -- a block element finishes rendering: `1 + element.margin` (a plain block
  -- contributes 1; a block with `margin = N` contributes `1 + N`, leaving
  -- N blank lines above and below itself, like CSS margin).  Margins between
  -- adjacent blocks collapse to the larger of the two.  Pure-whitespace text
  -- between block siblings is dropped without flushing, matching how browsers
  -- strip whitespace at block boundaries.
  local pending_break = 0

  -- Stack of active line prefixes (e.g. blockquote bars).
  local prefix_stack = {}

  -- Apply all active line prefixes to the current line.
  local function apply_prefixes()
    for _, prefix in ipairs(prefix_stack) do
      local start_col = col
      lines[line_idx] = lines[line_idx] .. prefix.text
      col = col + #prefix.text
      if prefix.hlgroup then
        table.insert(highlights, {
          hlgroup = prefix.hlgroup,
          start_pos = { line_idx - 1, start_col },
          end_pos = { line_idx - 1, col },
        })
      end
    end
  end

  -- Advance `n` lines, finalizing each line's width and reapplying any
  -- active prefixes (e.g. blockquote bars) to the freshly opened line.
  local function emit_newlines(n)
    for _ = 1, n do
      width = math.max(width, vim.fn.strdisplaywidth(lines[line_idx]))
      line_idx = line_idx + 1
      lines[line_idx] = ''
      col = 0
      has_content = false
      apply_prefixes()
    end
  end

  ---@param element Element
  local function go(element)
    if element.__async_init and renderer then
      renderer.pending_elements[element] = true
      element.__async_init(function(resolved_element) ---@type Element resolved_element
        -- Carry state (foldable open/close, RefreshComponent polling
        -- cancellation, ...) from the prior resolved subtree to the new
        -- one. Without this, every async frame would orphan whatever
        -- `__state` handles lived in the previous subtree — most
        -- noticeably leaking RefreshComponent polling loops that then
        -- compound into a render storm.
        local previous = element.__children[1]
        if previous then
          Element.transfer_state(previous, resolved_element)
        end
        element:set_children { resolved_element }
        renderer.pending_elements[element] = nil
        renderer:render()
      end)
      element.__async_init = nil -- only run once
    end

    -- Block elements start on a new line when following content; margined
    -- blocks add blank line(s) above (collapsing with the previous block's
    -- pending margin, like CSS).
    if element.is_block and (has_content or pending_break > 0) then
      emit_newlines(math.max(pending_break, has_content and 1 or 0, 1 + element.margin))
      pending_break = 0
    end

    -- Snapshot position so we can tell whether this element rendered
    -- anything (used to decide whether a closing block sets a pending break).
    local pre_render_line = line_idx
    local pre_render_col = col

    -- Push a line prefix (e.g. blockquote `│ `).
    local has_prefix = element.line_prefix ~= nil
    if has_prefix then
      table.insert(prefix_stack, element.line_prefix)
      -- Apply just the newly pushed prefix to the current line.
      local prefix = element.line_prefix
      local start_col = col
      lines[line_idx] = lines[line_idx] .. prefix.text
      col = col + #prefix.text
      if prefix.hlgroup then
        table.insert(highlights, {
          hlgroup = prefix.hlgroup,
          start_pos = { line_idx - 1, start_col },
          end_pos = { line_idx - 1, col },
        })
      end
    end

    local start_pos = { line_idx - 1, col }

    local text = element.text
    if text ~= '' and pending_break > 0 then
      if text:match '^%s*$' then
        -- Whitespace-only text between block siblings is decorative
        -- (source-formatting indentation).  Drop it without flushing so
        -- the pending break still applies to whatever comes next.
        text = ''
      else
        -- Real content arrives after a block: flush the deferred newline(s)
        -- and strip leading whitespace, matching CSS at a block boundary.
        emit_newlines(pending_break)
        pending_break = 0
        text = text:gsub('^%s+', '')
      end
    end
    if text ~= '' then
      local pos = 1
      while pos <= #text do
        local nl = text:find('\n', pos, true)
        if nl then
          local chunk = text:sub(pos, nl - 1)
          lines[line_idx] = lines[line_idx] .. chunk
          if #chunk > 0 then
            has_content = true
          end
          emit_newlines(1)
          pos = nl + 1
        else
          local rest = text:sub(pos)
          lines[line_idx] = lines[line_idx] .. rest
          col = col + #rest
          has_content = true
          break
        end
      end
    end

    for _, child in ipairs(element.__children) do
      go(child)
    end

    local end_pos = { line_idx - 1, col }
    positions[element] = { start_pos = start_pos, end_pos = end_pos }

    -- Reuse the position's `start_pos`/`end_pos` tables so the vertical-justify
    -- shift (which walks `positions`) moves the OSC 8 range along with them.
    if element.url then
      urls[#urls + 1] = { url = element.url, start_pos = start_pos, end_pos = end_pos }
    end

    local hlgroups = element.hlgroups
    if type(hlgroups) == 'function' then
      hlgroups = hlgroups(element)
    end
    if hlgroups then
      for _, hg in ipairs(hlgroups) do
        table.insert(highlights, { hlgroup = hg, start_pos = start_pos, end_pos = end_pos })
      end
    end

    -- Pop line prefix when leaving the element.
    if has_prefix then
      table.remove(prefix_stack)
    end

    -- A block that actually rendered something defers newline(s) so the
    -- next sibling (block or inline) starts on its own line — `1 + margin`
    -- newlines, leaving `margin` blank lines below.  We take the max with
    -- the existing pending_break so an inner margined block's margin
    -- survives leaving a non-margined parent (CSS margin collapse through
    -- edges).  Empty blocks contribute no break.
    if element.is_block and (line_idx ~= pre_render_line or col ~= pre_render_col) then
      pending_break = math.max(pending_break, 1 + element.margin)
    end
  end

  go(self)
  width = math.max(width, vim.fn.strdisplaywidth(lines[line_idx]))

  return {
    lines = lines,
    highlights = highlights,
    urls = urls,
    width = width,
    height = line_idx,
    positions = positions,
  }
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
    :gsub('(%a)([^_]*)', function(a, b)
      return a:upper() .. b
    end)
    :gsub('_', '')
  return ('<Plug>(LeanInfoview%s)'):format(pascal)
end

---Create a new BufRenderer.
function BufRenderer:new(obj)
  obj = obj or {}
  obj.pending_elements = {}
  -- Open interactive tooltips, keyed by `path_key` of the element that owns
  -- them. Kept here rather than on the elements so a rebuilt element tree
  -- doesn't strand them (see `make_event_context`).
  obj.tooltips = {}
  local new_renderer = setmetatable(obj, self)
  new_renderer.__overlays = OverlayState:new(new_renderer)
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
    require('lean.abbreviations').show_reverse_lookup,
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

  -- Ctrl+click rather than shift+click for the alternate action because
  -- most terminals (notably Kitty) reserve shift+click for native text
  -- selection.
  local function dispatch_mouse(event)
    local pos = vim.fn.getmousepos()
    if pos.winid == 0 or pos.line == 0 then
      return
    end
    if vim.api.nvim_win_get_buf(pos.winid) ~= buf.bufnr then
      return
    end
    local line_len = #buf:line(pos.line - 1)
    local col = math.max(0, math.min(pos.column - 1, line_len))
    local path = new_renderer:path_from_pos { pos.line - 1, col }
    Window:from_id(pos.winid):move_cursor { pos.line, col }
    if path then
      new_renderer:event(event, path)
    end
  end
  buf.keymaps:set('n', '<Plug>(LeanInfoviewMouseClick)', function()
    dispatch_mouse 'click'
  end, { desc = 'Fire a click event at the mouse position.' })
  buf.keymaps:set('n', '<Plug>(LeanInfoviewMouseSelect)', function()
    dispatch_mouse 'select'
  end, { desc = 'Fire a select event at the mouse position.' })
  buf.keymaps:set(
    'n',
    '<LeftMouse>',
    '<Plug>(LeanInfoviewMouseClick)',
    { remap = true, desc = 'Click on the element under the mouse.' }
  )
  buf.keymaps:set(
    'n',
    '<C-LeftMouse>',
    '<Plug>(LeanInfoviewMouseSelect)',
    { remap = true, desc = 'Select the element under the mouse.' }
  )

  for key, event in pairs(obj.keymaps or {}) do
    local rhs = element_event_set[event] and event_plug_name(event)
      or function()
        new_renderer:event(event)
      end
    buf.keymaps:set(
      'n',
      key,
      rhs,
      { remap = element_event_set[event], desc = ('Fire a %s event.'):format(event) }
    )
  end

  return new_renderer
end

---The window displaying this renderer was closed, but the buffer lives on.
---Cleans up resources that are tied to the window (e.g. terminal graphics).
function BufRenderer:detach_window()
  self:event 'clear_all' -- Ensure tooltips close.
  self.__overlays:close()
end

function BufRenderer:close()
  self:detach_window()
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

---Manages overlay lifecycle for a single BufRenderer.
---@class OverlayState
---@field private _renderer BufRenderer
---@field private _images? ImageSet
---@field private _handles? table<Element, integer>
---@field private _autocmd? integer
---@field private _augroup? integer
---@field private _id integer
---@field private _waiting boolean
OverlayState = {}
OverlayState.__index = OverlayState

local overlay_id_counter = 0

function OverlayState:new(renderer)
  overlay_id_counter = overlay_id_counter + 1
  return setmetatable({
    _renderer = renderer,
    _waiting = false,
    _id = overlay_id_counter,
  }, self)
end

function OverlayState:invalidate()
  if self._images then
    self._images:clear()
    self._images = nil
    self._handles = nil
  end
  -- Clear the scroll autocmd so render() re-registers for the (possibly new) window.
  if self._autocmd then
    pcall(vim.api.nvim_del_autocmd, self._autocmd)
    self._autocmd = nil
  end
  if self._augroup then
    pcall(vim.api.nvim_del_augroup_by_id, self._augroup)
    self._augroup = nil
  end
end

function OverlayState:close()
  self._waiting = false
  self:invalidate()
end

---Check whether the current set of overlay elements has changed and
---update images with the least flicker possible.
function OverlayState:update()
  local renderer = self._renderer
  if not renderer.positions then
    self:invalidate()
    return
  end

  -- Collect the current set of overlay elements.
  local current = {}
  for element, _ in pairs(renderer.positions) do
    if element.overlay then
      current[#current + 1] = element
    end
  end

  -- If the set of overlay elements is identical (by identity) to what
  -- we already transmitted, skip the expensive invalidate+re-transmit
  -- and just re-place for the (possibly new) positions.
  if self._images and self._handles then
    local dominated = true
    for _, element in ipairs(current) do
      if not self._handles[element] then
        dominated = false
        break
      end
    end
    if dominated and #current == self._images:count() then
      self:render()
      return
    end
  end

  -- Wrap the delete+rebuild in synchronized output so the terminal
  -- renders both as one atomic frame, eliminating flicker.
  vim.api.nvim_chan_send(2, '\x1b[?2026h')
  self:invalidate()
  self:render()
  vim.api.nvim_chan_send(2, '\x1b[?2026l')
end

function OverlayState:render()
  local renderer = self._renderer
  if not renderer.positions then
    return
  end

  local config = require 'lean.config'()
  if config.graphics.enabled == false then
    return
  end

  local kitty = require 'kitty'
  if not kitty.available() then
    if not self._waiting then
      self._waiting = true
      kitty.on_available(function()
        vim.schedule(function()
          if self._waiting and renderer.buffer:is_loaded() and renderer.positions then
            self:render()
          end
        end)
      end)
    end
    return
  end

  -- Find a window showing this buffer (last_window may not be set yet).
  local win = renderer.last_window and renderer.last_window:is_valid() and renderer.last_window
  if not win then
    local wins = vim.fn.win_findbuf(renderer.buffer.bufnr)
    if #wins == 0 then
      return
    end
    win = Window:from_id(wins[1])
  end

  ---Element positions are byte offsets, but kitty places images at screen
  ---cells, which diverge on lines containing multibyte characters.
  ---@param pos { start_pos: integer[] }
  ---@return { row: integer, col: integer }
  local function display_pos(pos)
    local row, byte_col = pos.start_pos[1], pos.start_pos[2]
    local col = byte_col
    if byte_col > 0 then
      local line = vim.api.nvim_buf_get_lines(renderer.buffer.bufnr, row, row + 1, false)[1] or ''
      col = vim.fn.strdisplaywidth(line:sub(1, byte_col))
    end
    return { row = row, col = col }
  end

  ---@type table<integer, { row: integer, col: integer }>
  local positions = {}
  local needs_rebuild = not self._images

  if needs_rebuild then
    self._images = kitty.ImageSet:new()
    self._handles = {}

    for element, pos in pairs(renderer.positions) do
      if element.overlay then
        local handle = self._images:add(
          element.overlay.data,
          element.overlay.width,
          element.overlay.height,
          element.overlay.format
        )
        self._handles[element] = handle
        positions[handle] = display_pos(pos)
      end
    end
  else
    for element, pos in pairs(renderer.positions) do
      local handle = self._handles[element]
      if handle then
        positions[handle] = display_pos(pos)
      end
    end
  end

  self._images:place_all(win, positions)

  if next(positions) and not self._autocmd then
    local winid = win.id
    local group = vim.api.nvim_create_augroup('LeanOverlay' .. self._id, { clear = true })
    self._augroup = group

    self._autocmd = vim.api.nvim_create_autocmd('WinScrolled', {
      group = group,
      pattern = tostring(winid),
      callback = function()
        if renderer.positions then
          self:render()
        end
      end,
    })

    vim.api.nvim_create_autocmd('VimResized', {
      group = group,
      callback = function()
        if renderer.buffer:is_loaded() then
          renderer:render()
        end
      end,
    })
  end
end

-- Where a single flex item lands for each CSS `justify-content` value (see
-- `BufRenderer.justify_content`). The distribution values (`space-*`) only
-- differ from the packing ones when there is more than one item, so per the
-- spec they collapse here to their single-item behaviour: `space-between`
-- packs at the start; `space-around` and `space-evenly` centre.
---@type table<JustifyContent, 'start'|'center'|'end'>
local JUSTIFY_PACKING = {
  start = 'start',
  ['flex-start'] = 'start',
  ['space-between'] = 'start',
  center = 'center',
  ['space-around'] = 'center',
  ['space-evenly'] = 'center',
  ['end'] = 'end',
  ['flex-end'] = 'end',
}

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

  local packing = JUSTIFY_PACKING[self.justify_content or 'start']

  if packing == 'center' or packing == 'end' then
    -- Justify the content along the block (vertical) axis within its window,
    -- as a column flexbox would. We pad from the top with real blank lines
    -- rather than virtual lines, which Neovim won't display above the first
    -- line; that shifts everything down, so the highlights and the position
    -- map are offset to match. The padding is recomputed on every render, so
    -- it tracks window resizes.
    local window = self.buffer:windows():next()
    local slack = window and (window:height() - result.height) or 0
    -- Padding can only push content *down*, and a buffer can't scroll above
    -- its first line, so when the content overflows the window (slack <= 0) it
    -- stays pinned at the top whatever the packing — the only thing we can
    -- express. Otherwise 'center' splits the slack and 'end' takes all of it.
    local pad = packing == 'center' and math.floor(slack / 2) or slack
    if pad > 0 then
      local padding = {}
      for i = 1, pad do
        padding[i] = ''
      end
      result.lines = vim.list_extend(padding, result.lines)
      -- Each element's highlight shares its `start_pos`/`end_pos` tables with
      -- its position-map entry (see `render_lines`), so shift each table only
      -- once, or shared tables would be double-counted.
      local shifted = {}
      local function shift(pos)
        if pos and not shifted[pos] then
          shifted[pos] = true
          pos[1] = pos[1] + pad
        end
      end
      for _, hl in ipairs(result.highlights) do
        shift(hl.start_pos)
        shift(hl.end_pos)
      end
      for _, span in pairs(result.positions) do
        shift(span.start_pos)
        shift(span.end_pos)
      end
      -- `urls` reuse the position tables shifted just above; `shifted` dedups,
      -- so this is belt-and-suspenders should that ever stop holding.
      for _, link in ipairs(result.urls) do
        shift(link.start_pos)
        shift(link.end_pos)
      end
    end
  end

  self.positions = result.positions
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

  -- Associate any link URLs with their text via an extmark; in the TUI Neovim
  -- emits the OSC 8 control sequence for these, so supporting terminals render
  -- them as natively clickable hyperlinks.
  for _, link in ipairs(result.urls) do
    self.buffer:set_extmark(self.__tui_ns, link.start_pos[1], link.start_pos[2], {
      end_row = link.end_pos[1],
      end_col = link.end_pos[2],
      url = link.url,
    })
  end

  if self.path then
    -- on a rerender any previously existing paths may be invalid
    local _, leaf = self.element:div_from_path(self.path)
    local ep = leaf and self.positions[leaf]
    if not ep then
      self.path = nil
    elseif self:last_window_valid() then
      local position = self.path[#self.path].position
      local pos = (
        position
        and not pos_before(position, ep.start_pos)
        and pos_before(position, ep.end_pos)
      )
          and position
        or ep.start_pos
      self.last_window:set_cursor { pos[1] + 1, pos[2] }
    end
  end

  self:hover(true)

  self.__overlays:update()
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

---A stable, tree-independent key for a path.
---
---It encodes only each node's identity (name and index), the same fields
---`path_equal` compares, ignoring cursor-specific metadata like offsets. Two
---structurally identical rebuilds therefore produce the same key, so interaction
---state keyed by this survives a rebuild without being carried across trees.
---@param path PathNode[]
---@return string
local function path_key(path)
  local field_sep, node_sep = string.char(31), string.char(30) -- unit/record separators
  local parts = {}
  for i, node in ipairs(path) do
    parts[i] = tostring(node.name) .. field_sep .. tostring(node.idx)
  end
  return table.concat(parts, node_sep)
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
  local new_path = self:path_from_pos { cursor_pos[1] - 1, cursor_pos[2] }
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
  -- A tooltip is either static (attached to the element, e.g. a link's URL) or
  -- an open interactive tooltip, whose content lives in the renderer's store
  -- keyed by path so it survives element-tree rebuilds.
  local hover_element, tt_parent_element, new_tooltip_element
  local tt_parent_element_path
  for i = #stack, 1, -1 do
    if not hover_element and stack[i].highlightable then
      hover_element = stack[i]
    end
    if not tt_parent_element then
      local subpath = vim.list_slice(path, 1, i)
      local key = stack[i].tooltip_id or path_key(subpath)
      local content = stack[i].tooltip or self.tooltips[key]
      if content then
        tt_parent_element = stack[i]
        tt_parent_element_path = subpath
        new_tooltip_element = content
      end
    end
    if hover_element and tt_parent_element then
      break
    end
  end

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

    -- The anchor window can be gone by the time an async update lands
    -- (e.g. the tooltip chain was dismissed while we were rendering).
    if
      not self.tooltip:last_window_valid()
      and self.last_window
      and self.last_window:is_valid()
    then
      self.tooltip.last_window = self.last_window:float {
        buffer = self.tooltip.buffer,
        enter = false,
        noautocmd = true, -- avoid firing update_cursor by disabling the autocmds
        style = 'minimal',
        width = self.tooltip.width,
        height = self.tooltip.height,
        border = 'rounded',
        bufpos = self.positions[tt_parent_element].start_pos,
        zindex = 50 + self.tooltip.buffer.bufnr, -- later tooltips are guaranteed to have greater buffer handles
      }
    end
  end

  if hover_element then
    local hp = self.positions[hover_element]
    self.hover_range = { hp.start_pos, hp.end_pos }
  else
    self.hover_range = nil
  end

  if force_update_highlight or not vim.deep_equal(old_hover_range, self.hover_range) then
    self.buffer:clear_namespace(self.__hl_ns)
    local hlgroup = 'widgetElementHighlight'
    if self.hover_range then
      vim.hl.range(
        self.buffer.bufnr,
        self.__hl_ns,
        hlgroup,
        self.hover_range[1],
        self.hover_range[2]
      )
    end
  end
end

---Fire an event.
---@param event ElementEvent
---@param path? PathNode[]
---@return nil
function BufRenderer:event(event, path, ...)
  local args = { ... }

  -- Without a path we can still dispatch to handlers on the root element. This
  -- matters for cleanup events (e.g. `clear`) fired from autocmds before the
  -- cursor has ever moved into the buffer, when self.path is still nil.
  path = path or self.path or {}

  if
    not self.element:event(path, event, self:make_event_context(path), unpack(args)) and self.parent
  then
    -- bubble up to parent
    return self.parent:event(event, self.parent_path, ...)
  end
end

---@class ElementEventContext
---@field rerender fun():nil
---@field rehover fun():nil
---@field jump_to_last_window fun():nil Jump to the last window the cursor came from.
---@field tooltip_open fun():boolean Whether this event's element has an open tooltip.
---@field set_tooltip fun(content: Element):nil Open (or replace) this event's tooltip.
---@field clear_tooltip fun():nil Close this event's tooltip, if open.
---@field clear_all_tooltips fun():nil Close every open tooltip in this renderer.

---@param event_path? PathNode[] the path the event fired at (defaults to the cursor path)
---@return ElementEventContext
function BufRenderer:make_event_context(event_path)
  -- Interactive tooltips are owned by the innermost clickable element along the
  -- event's path, keyed by `path_key` rather than stored on the element itself.
  -- The key is recomputed against the *current* tree, so a handler whose async
  -- work resolves after a rebuild still keys the live tree (a rebuild that keeps
  -- the same content keeps the same key) instead of a stranded element.
  local function tooltip_key()
    local path = event_path or self.path
    if not path then
      return nil
    end
    local element, _, subpath = self.element:find_innermost_along(path, function(_, each)
      return each.events and each.events.click
    end)
    if not element then
      return nil
    end
    return element.tooltip_id or path_key(subpath)
  end

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
    tooltip_open = function()
      local key = tooltip_key()
      return key ~= nil and self.tooltips[key] ~= nil
    end,
    set_tooltip = function(content)
      local key = tooltip_key()
      if key then
        self.tooltips[key] = content
      end
    end,
    clear_tooltip = function()
      local key = tooltip_key()
      if key then
        self.tooltips[key] = nil
      end
    end,
    clear_all_tooltips = function()
      self.tooltips = {}
      -- Close the open float directly rather than via `hover`; `close` re-fires
      -- `clear_all` (through `detach_window`), so clear `self.tooltip` first to
      -- keep that bounce from recursing back in here.
      local tooltip = self.tooltip
      self.tooltip = nil
      if tooltip then
        tooltip:close()
      end
    end,
  }
end

---Get the (0-indexed) {line, col} position of the element arrived at by following the given path.
---@param path PathNode[] the path to follow
---@return integer[]? the {line, col} position if the path was valid, nil otherwise
function BufRenderer:pos_from_path(path)
  if not self.positions then
    return nil
  end

  local _, element = self.element:div_from_path(path)
  if not element then
    return nil
  end

  local ep = self.positions[element]
  if not ep then
    return nil
  end

  -- Use the stored cursor position if it's still within the element's range.
  local position = path[#path].position
  if position and not pos_before(position, ep.start_pos) and pos_before(position, ep.end_pos) then
    return position
  end

  return ep.start_pos
end

---Get the path at the given (0-indexed) {line, col} cursor position.
---@param pos integer[] {line, col} position (0-indexed)
---@return PathNode[]? the path at this position
---@return Element[]? the stack of elements along this path
function BufRenderer:path_from_pos(pos)
  if not self.positions then
    return nil
  end

  local element = self.element
  local positions = self.positions
  local path = { { idx = 0, name = element.name } }
  local stack = { element }

  while true do
    local ep = positions[element]
    if not ep then
      return nil
    end

    -- Where does this element's own text end (i.e. where do children begin)?
    local first_child = element.__children[1]
    local text_end = first_child and positions[first_child].start_pos or ep.end_pos

    -- Is pos within this element's own text?
    if pos_before(pos, text_end) then
      path[#path].position = pos
      return path, stack
    end

    -- Find which child contains pos.
    local descended = false
    for idx, child in ipairs(element.__children) do
      local cp = positions[child]
      if not cp then
        return nil
      end
      if pos_before(pos, cp.end_pos) then
        table.insert(path, { idx = idx, name = child.name })
        table.insert(stack, child)
        element = child
        descended = true
        break
      end
    end

    if not descended then
      return nil
    end
  end
end

---Convert an element path to a (1,0)-indexed buffer position.
---@param path PathNode[]
---@return {[1]: integer, [2]: integer}? pos 1-indexed line, 0-indexed column
function BufRenderer:buf_position_from_path(path)
  local pos = self:pos_from_path(path)
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
    start_selected = function(_)
      return true
    end,
    title = 'Select one or more of:',
  })

  local modal = (opts.relative_window or Window:current()):modal {
    enter = true,
    style = 'minimal',
    border = 'rounded',
    title = opts.title,
    footer = '<Tab>: toggle, <CR>: confirm, <Esc>: cancel',
    footer_pos = 'center',
    bufpos = { 100, 10 },
    width = 50,
    height = #choices + 2,
    zindex = 50,
  }
  modal.window.o.winfixbuf = true

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
    children = vim
      .iter(ipairs(choices))
      :map(function(i, choice)
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
          },
        }
        return self
      end)
      :totable(),

    events = {
      make_selection = function(_)
        modal:dismiss()
        local chosen = {}
        local unchosen = {}
        vim.iter(ipairs(choices)):each(function(i, choice)
          local into = selected[i] and chosen or unchosen
          table.insert(into, choice)
        end)
        on_choices(chosen, unchosen)
      end,
      clear = function(_)
        modal:dismiss()
      end,
    },
  }

  local renderer = element:renderer {
    buffer = modal.buffer,
    keymaps = {
      ['K'] = 'click',
      ['<Tab>'] = 'toggle',
      ['<CR>'] = 'make_selection',
      ['<Esc>'] = 'clear',
    },
  }
  renderer:render()
  modal:attach(renderer):dismiss_on_leave()

  -- the 'real' editable region where entries are
  local start_line = 2
  local end_line = #choices + 1
  local first_column = 5

  modal.window:set_cursor { start_line, first_column }

  modal.buffer:create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    callback = function() -- clip the cursor to the real editable region
      local row, column = unpack(modal.window:cursor())
      row = math.max(math.min(row, end_line), start_line)
      column = math.max(column, first_column)
      modal.window:set_cursor { row, column }
    end,
  })
end

---Create a plain text Element.
---@param str string
---@return Element
function Element.text(str)
  return Element:new { text = str }
end

return {
  BufRenderer = BufRenderer,
  Element = Element,
  select_many = select_many,
}
