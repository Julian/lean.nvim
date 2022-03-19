local async = require('plenary.async')

local util = require('lean._util')

---An individual console user interface element.
---@class Element
---@field events table<string, fun()> @event function map
---@field text string @the text to show when rendering this element
---@field name string @a named handle for this element, used when path-searching
---@field hlgroup? string|fun():string @the highlight group for this element's text, or a function that returns it
---@field tooltip? Element Optional tooltip
---@field highlightable boolean @(for buffer rendering) whether to highlight this element when hovering over it
---@field _size? integer Computed size of this element, updated by `Element:to_string`
---@field disable_update? boolean
---@field private __children Element[] @this element's children
local Element = {}
Element.__index = Element

---Renders elements within a specific buffer.
---@class BufRenderer
---@field buf integer Buffer number of the buffer the element renders to
---@field element Element the element rendered by this renderer
---@field lines? string[] Rendered lines.
---@field path? PathNode[] Current cursor path
---@field last_win? integer Window number of the last event
---@field keymaps table Extra keymaps (inherited by tooltips)
---@field hover_range? integer[][] (0,0)-range of the highlighted node
---@field tooltip? BufRenderer currently open tooltip
---@field parent? BufRenderer Parent renderer
---@field parent_path? PathNode[] Path in parent element, events bubble up to the parent there
local BufRenderer = {
  __widgets_ns = vim.api.nvim_create_namespace('lean.widgets'),
  __hl_ns = vim.api.nvim_create_namespace('lean.highlights')
}
BufRenderer.__index = BufRenderer

---@class ElementNewArgs
---@field events table<string, fun()> @event function map
---@field text string @the text to show when rendering this element
---@field name string @a named handle for this element, used when path-searching
---@field hlgroup? string|fun():string @the highlight group for this element's text, or a function that returns it
---@field highlightable boolean @(for buffer rendering) whether to highlight this element when hovering over it
---@field children Element[] @this element's children

---Create a new Element.
---@param args ElementNewArgs
---@return Element
function Element:new(args)
  args = args or {}
  local obj = {
    text = args.text or '',
    name = args.name or '',
    hlgroup = args.hlgroup,
    highlightable = args.highlightable,
    __children = args.children or {},
    events = args.events or {},
  }
  return setmetatable(obj, self)
end

---@param children? Element[]
function Element:set_children(children)
  self.__children = children or {}
end

---Add a child to this element.
---@param child Element @child element to add
---@return Element @the added child
function Element:add_child(child)
  table.insert(self.__children, child)
end

---Set this element's tooltip.
---@param element Element @element to use as a tooltip for this element
---@return Element @the added tooltip element
function Element:add_tooltip(element)
  self.tooltip = element
  return element
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
    if type(hlgroup) == "function" then
      hlgroup = hlgroup(element)
    end
    if hlgroup then
      table.insert(hls, {
        start = pos,
        ["end"] = pos + element._size,
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
---@field idx number @the index in the current element's children to follow
---@field name string @the name that the indexed child should have
---@field offset number|nil @if provided, a byte offset from the beginning of this element

---Get the raw byte position of the element arrived at by following the given path.
---@param path PathNode[] @the path to follow
---@return number|nil @the position if the path was valid, nil otherwise
---@return number|nil @the additional byte offset from the position if the path was valid, nil otherwise
function Element:pos_from_path(path)
  local pos = 1
  for i, p in ipairs(path) do
    if i == 1 then -- first path node encodes root
      if p.name ~= self.name then return nil end
    else
      if #self.__children < p.idx then return nil end
      pos = pos + #self.text
      for j = 1, p.idx - 1 do pos = pos + self.__children[j]._size end
      self = self.__children[p.idx]
    end
  end
  local offset = path[#path].offset or 0
  -- in case this is an invalid or outdated path
  offset = (#self.text - 1 >= offset) and offset
  offset = offset or 0
  return pos, offset
end

---Get the element stack and element arrived at by following the given path.
---@param path PathNode[] @the path to follow
---@return Element[]|nil @the stack of elements at this path, or nil if the path is invalid
---@return Element|nil @the element at this path, or nil if the path is invalid
function Element:div_from_path(path)
  local stack = { self }
  for i, p in ipairs(path) do
    if i == 1 then -- first path node encodes root
      if p.name ~= self.name then return nil, nil end
    else
      if #self.__children < p.idx then return nil, nil end
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
  for i = 1, n do table.insert(res, arr[i]) end
  return res
end

-- Finds the innermost element satisfying a predicate
---@param path PathNode[]
---@param check fun(element:Element):boolean
---@return Element @The element satisfying check
---@return Element[] @The element stack up to and including that element
---@return PathNode[] @The subpath up to that element
function Element:find_innermost_along(path, check)
  local stack, _ = self:div_from_path(path)
  if stack == nil then return end

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
    if not lines[i] then return end
    raw_pos = raw_pos + #(lines[i]) + 1
  end
  if not lines[pos[1]] or (#lines[pos[1]] == 0 and pos[2] ~= 0) or
    (#lines[pos[1]] > 0 and pos[2] + 1 > #lines[pos[1]]) then
    return
  end
  raw_pos = raw_pos + pos[2] + 1
  return raw_pos
end

-- returns (0, 0)-indexed cursor position from raw byte position and list of lines
local function raw_pos_to_pos(raw_pos, lines)
  local line_num = 0
  local rem_chars = raw_pos

  for _, line in ipairs(lines) do
    line_num = line_num + 1
    if rem_chars <= (#line + 1) then return {line_num - 1, rem_chars - 1} end

    rem_chars = rem_chars - (#line + 1)
  end
end

---Get the path at the given raw byte position.
---(requires previous call to Element:to_string)
---@param pos integer byte position
---@return PathNode[]|nil the path at this position
---@return Element[]|nil the stack of elements along this path
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
    if child._size == nil then return nil end
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
---@param path PathNode[] @the path to trigger the event at
---@param event_name string @the path to trigger the event at
function Element:event(path, event_name, ...)
  local event_element = self:find_innermost_along(path,
    ---@param element Element
    function (element) return element.events and element.events[event_name] end)
  if not event_element then
    return false
  end

  local args = {...}

  async.void(function()
    return event_element.events[event_name](unpack(args))
  end)()
  return true
end

---Returns the first element matching the given check function.
---Searches first this element itself, then its children, then its tooltip.
---@param check fun(element:Element):boolean
function Element:find(check)
  if check(self) then return self end

  local found
  for _, child in ipairs(self.__children) do
    found = child:find(check)
    if found then return found end
  end

  if self.tooltip then
    found = self.tooltip:find(check)
    if found then return found end
  end
end

function Element:__filter(path, pos, fn)
  pos = pos + #self.text

  for idx, child in ipairs(self.__children) do
    local new_path = {unpack(path)}
    table.insert(new_path, {idx = idx, name = child.name})
    fn(child, new_path, pos)

    pos = child:__filter(new_path, pos, fn)
  end

  return pos
end

function Element:filter(fn)
  local path = {{idx = -1, name = self.name}}
  local pos = 1
  fn(self, path, pos)

  self:__filter(path, pos, fn)
end

-- Creates an impotent deep copy of this element (both tag-stripped and event-disabled).
function Element:dummy_copy()
  local dummy = Element:new{ text = self.text, name = self.name, hlgroup = self.hlgroup }
  dummy.highlightable = self.highlightable
  for _, child in ipairs(self.__children) do
    table.insert(dummy.__children, child:dummy_copy())
  end
  if self.tooltip then
    dummy.tooltip = self.tooltip:dummy_copy()
  end
  return dummy
end

---Create an element which joins a list-like table of elements with the provided separator.
---@param elements Element[]
---@param sep string
---@return Element
function Element:concat(elements, sep)
  local children = {}
  for index, child in ipairs(elements) do
    if index > 1 then table.insert(children, Element:new{ text = sep }) end
    table.insert(children, child)
  end
  return self:new{ children = children }
end

---Create a BufRenderer that renders this Element.
---@param obj table
function Element:renderer(obj)
  return BufRenderer:new(vim.tbl_extend("error", obj, { element = self }))
end

-- Maps BufRenderer.buf to BufRenderer
--- @type table<number, BufRenderer>
local _by_buf = {}

-- Clean up references to closed buffers in the `_by_buf` table.
-- It doesn't seem to possibly to reliably detect the deletion of buffers in
-- neovim, so we just call this function regularly.
local function gc()
  for bufnr, _ in pairs(_by_buf) do
    if not vim.api.nvim_buf_is_valid(bufnr) then
      _by_buf[bufnr] = nil
    end
  end
end

---Create a new BufRenderer.
function BufRenderer:new(obj)
  gc()

  obj = obj or {}
  local new_renderer = setmetatable(obj, self)
  vim.api.nvim_buf_set_option(obj.buf, "modifiable", false)
  _by_buf[obj.buf] = new_renderer

  util.set_augroup("WidgetPosition", string.format([[
    autocmd CursorMoved <buffer=%d> lua require'lean.widgets'._by_buf[%d]:update_cursor()
    autocmd BufEnter <buffer=%d> lua require'lean.widgets'._by_buf[%d]:update_cursor()
  ]], obj.buf, obj.buf, obj.buf, obj.buf), obj.buf)

  local mappings = {
    n = {
      ['<Tab>'] = ([[<Cmd>lua require'lean.widgets'._by_buf[%d]:enter_tooltip()<CR>]]):format(obj.buf),
      ['<S-Tab>'] = ([[<Cmd>lua require'lean.widgets'._by_buf[%d]:goto_parent_tooltip()<CR>]]):format(obj.buf),
      ['J'] = ([[<Cmd>lua require'lean.widgets'._by_buf[%d]:enter_tooltip()<CR>]]):format(obj.buf),
      ['S'] = ([[<Cmd>lua require'lean.widgets'._by_buf[%d]:hop_to()<CR>]]):format(obj.buf),
      ['<LocalLeader>\\'] = '<Cmd>LeanAbbreviationsReverseLookup<CR>',
    }
  }
  for key, event in pairs(obj.keymaps or {}) do
    mappings.n[key] = ([[<Cmd>lua require'lean.widgets'._by_buf[%d]:event("%s")<CR>]]):format(obj.buf, event)
  end
  util.load_mappings(mappings, obj.buf)

  return new_renderer
end

---@param keep_tooltips_open? boolean
function BufRenderer:close(keep_tooltips_open)
  if vim.api.nvim_buf_is_valid(self.buf) then
    vim.api.nvim_buf_delete(self.buf, {force = true})
    gc()
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

  if not vim.api.nvim_buf_is_valid(buf) then return end

  vim.api.nvim_buf_clear_namespace(buf, self.__widgets_ns, 0, -1)

  local text = self.element:to_string()
  local lines = vim.split(text, '\n')
  self.lines = lines

  local hls = self.element:_get_highlights()

  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  -- HACK: This shouldn't really do anything, but I think there's a neovim
  --       display bug. See #27 and neovim/neovim#14663. Specifically,
  --       as of NVIM v0.5.0-dev+e0a01bdf7, without this, updating a long
  --       infoview with shorter contents doesn't properly redraw.
  vim.api.nvim_buf_call(buf, vim.fn.winline)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  for _, hl in ipairs(hls) do
    local start_pos = raw_pos_to_pos(hl.start, lines)
    local end_pos = raw_pos_to_pos(hl["end"], lines)
    vim.highlight.range(buf, self.__widgets_ns, hl.hlgroup, start_pos, end_pos)
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
  if self.disable_update then return end
  win = win or vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) == self.buf then
    self.last_win = win
  end
  if not self:last_win_valid() then return end

  local path_changed = self:update_position()

  if path_changed then
    self:hover()
  end
end

--- Checks if two paths are equal, ignoring auxillary metadata (e.g. offsets)
---@param path_a PathNode[] @first path
---@param path_b PathNode[] @second path
local function path_equal(path_a, path_b)
  if path_a == nil and path_b == nil then return true end
  if not path_a or not path_b then return false end
  if #path_a ~= #path_b then return false end

  for i, _ in ipairs(path_a) do
    if path_a[i].idx ~= path_b[i].idx then return false end
    if path_a[i].name ~= path_b[i].name then return false end
  end

  return true
end

function BufRenderer:update_position()
  local path_before = self.path
  local cursor_pos = vim.api.nvim_win_get_cursor(self.last_win)
  local raw_pos = pos_to_raw_pos(cursor_pos, self.lines)
  if not raw_pos then return end

  self.path = self.element:path_from_pos(raw_pos)

  if not path_equal(path_before, self.path) then
    self:event("cursor_leave", path_before)
    self:event("cursor_enter", self.path)
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

  local hover_element, _, hover_element_path = self.element:find_innermost_along(path,
    ---@param element Element
    function (element) return element.highlightable end)

  local tt_parent_element, _, tt_parent_element_path = self.element:find_innermost_along(path,
    ---@param element Element
    function (element) return element.tooltip end)

  local new_tooltip_element = tt_parent_element and tt_parent_element.tooltip

  if self.tooltip ~= nil and new_tooltip_element == nil then
    self.tooltip:close()
    self.tooltip = nil
  end

  if new_tooltip_element ~= nil then
    local width, height = util.make_floating_popup_size(vim.split(new_tooltip_element:to_string(), "\n"))

    local tt_parent_path = tt_parent_element_path
    local bufpos = raw_pos_to_pos(self.element:pos_from_path(tt_parent_path), self.lines)

    if self.tooltip then -- reuse old tooltip window
      -- FIXME: Some method call instead of mutating attributes
      self.tooltip.element = new_tooltip_element
      self.tooltip.parent = self
      self.tooltip.parent_path = tt_parent_element_path
    else
      self.tooltip = new_tooltip_element:renderer{
        buf = util.create_buf{
          listed = false,
          scratch = true,
          options = { bufhidden = 'wipe' },
        },
        keymaps = self.keymaps,
        parent = self,
        parent_path = tt_parent_element_path
      }
    end

    local win_options = {
      relative = "win",
      win = self.last_win,
      style = "minimal",
      width = width,
      height = height,
      border = "rounded",
      bufpos = bufpos,
      zindex = 50 + self.tooltip.buf -- later tooltips are guaranteed to have greater buffer handles
    }

    if not self.tooltip:last_win_valid() then
      -- fresh non-reused tooltip, open window
      self.tooltip.disable_update = true
      self.tooltip.last_win = vim.api.nvim_open_win(self.tooltip.buf, false, win_options)
      self.tooltip.disable_update = false
      -- workaround for neovim/neovim#13403, as it seems this wasn't entirely resolved by neovim/neovim#14770
      vim.api.nvim_command("redraw")
      self.tooltip.last_win_options = vim.deepcopy(win_options)
    elseif not vim.deep_equal(win_options, self.tooltip.last_win_options) then
      vim.api.nvim_win_set_config(self.tooltip.last_win, win_options)
      vim.api.nvim_command("redraw")
      self.tooltip.last_win_options = vim.deepcopy(win_options)
    end

    self.tooltip:render()
  end

  if hover_element_path and hover_element then
    local a = self.element:pos_from_path(hover_element_path)
    local start_pos = raw_pos_to_pos(a, self.lines)
    local end_pos = raw_pos_to_pos(a + hover_element._size, self.lines)
    self.hover_range = {start_pos, end_pos}
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

function BufRenderer:event(event, path, ...)
  local args = {...}

  path = path or self.path

  if not path then return end

  if not self.element:event(path, event, self:make_event_context(), unpack(args)) and self.parent then
    -- bubble up to parent
    return self.parent:event(event, self.parent_path, ...)
  end
end

---@class ElementEventContext
---@field rerender fun()
---@field rehover fun()
---@field self BufRenderer

---@return ElementEventContext
function BufRenderer:make_event_context()
  return {
    rerender = function() self:render() end,
    rehover = function() self:hover() end,
    self = self,
  }
end

function BufRenderer:enter_win()
  local deepest_tooltip = self:get_deepest_tooltip()
  if deepest_tooltip:last_win_valid() then
    vim.api.nvim_set_current_win(deepest_tooltip.last_win)
  end
end

function BufRenderer:get_deepest_tooltip()
  while self.tooltip do
    self = self.tooltip
  end
  return self
end

function BufRenderer:get_root_ancestor()
  while self.parent do
    self = self.parent
  end
  return self
end

function BufRenderer:hop_to()
  self:get_root_ancestor()
      :hop(function(element) return element.highlightable end, require"hop.hint_util".callbacks.win_goto)
end

function BufRenderer:hop(filter_fn, callback_fn)
  local winpos = vim.api.nvim_win_get_position(0)
  local strategy = {
    get_hint_list = function()
      local hints = {}
      local windows = {}

      ---@param root BufRenderer
      local function get_hints(root)
        local this_buf = root.buf
        local this_win = root.last_win
        if not this_win then return end
        table.insert(windows, this_win)
        local lines = root.lines
        local window_dist = require"hop.hint_util".manh_dist(winpos, vim.api.nvim_win_get_position(this_win))

        root.element:filter(function(element, _, raw_pos)
          if not filter_fn(element) then return end
          local pos = raw_pos_to_pos(raw_pos, lines)
          local hint =
          {
            line = pos[1] + 1,
            col = pos[2] + 1,
            buf = this_buf,
          }

          -- extra metadata
          hint.dist = require"hop.hint_util".manh_dist(vim.api.nvim_win_get_cursor(this_win),
            {hint.line, hint.col - 1})
          hint.wdist = window_dist
          hint.win = this_win

          -- prevent duplicate hints; this works because we are pre-order traversing the element tree
          if not vim.deep_equal(hint, hints[#hints]) then
            table.insert(hints, hint)
          end
        end)

        if root.tooltip then
          get_hints(root.tooltip)
        end
      end

      get_hints(self)

      -- just for greying out
      self.disable_update = true
      local views_data = require"hop.hint_util".create_views_data(windows)
      self.disable_update = false

      return hints, {grey_out = require"hop.hint_util".get_grey_out(views_data)}
    end,
    callback = callback_fn,
    comparator = require"hop.hint_util".comparators.win_cursor_dist_comparator
  }

  require"hop".hint(strategy)
end

return { BufRenderer = BufRenderer, Element = Element, _by_buf = _by_buf }
