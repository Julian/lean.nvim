local async = require"plenary.async"
local util = require"lean._util"

---An HTML-style div.
---@class Div
---@field events table<string, fun()> @event function map
---@field text string @the text to show when rendering this div
---@field name string @a named handle for this div, used when path-searching
---@field hlgroup string|fun():string @the highlight group for this div's text, or a function that returns it
---@field divs Div[] @this div's child divs
---@field tooltip? Div Optional tooltip
---@field highlightable boolean @(for buffer rendering) whether to highlight this div when hovering over it
---@field _size? integer Computed size of this div, updated by `Div:to_string`
---@field disable_update? boolean
local Div = {}
Div.__index = Div

---Create a new div.
---@param text string @the text to show when rendering this div
---@param name string @a named handle for this div, used when path-searching
---@param hlgroup string @the highlight group used for this div's text
---@return Div
function Div:new(text, name, hlgroup)
  local new_div = setmetatable({
    events = {},
    text = text or "",
    name = name or "",
    hlgroup = hlgroup,
    divs = {},
  }, self)
  return new_div
end

---Add a div to this div's `divs`.
---@param div Div @child div to add to this div's `divs`
---@return Div @the added div
function Div:add_div(div)
  table.insert(self.divs, div)
  return div
end

---Set this div's tooltip.
---@param div Div @div to use as a tooltip for this div
---@return Div @the added tooltip div
function Div:add_tooltip(div)
  self.tooltip = div
  return div
end

--- Insert a div initialized with the given params.
---@param text string
---@param name string
---@param hlgroup string
---@return Div @the added div
function Div:insert_div(text, name, hlgroup)
  return self:add_div(Div:new(text, name, hlgroup))
end

---@class DivHighlight
---@field start integer
---@field end integer
---@field hlgroup string

---@return DivHighlight[]
function Div:_get_highlights()
  local hls = {} ---@type DivHighlight[]

  ---@param div Div
  ---@param pos integer
  local function go(div, pos)
    local hlgroup = div.hlgroup
    if type(hlgroup) == "function" then
      hlgroup = hlgroup(div)
    end
    if hlgroup then
      table.insert(hls, {
        start = pos,
        ["end"] = pos + div._size,
        hlgroup = hlgroup,
      })
    end

    pos = pos + #div.text
    for _, child in ipairs(div.divs) do
      go(child, pos)
      pos = pos + child._size
    end
  end

  go(self, 1)

  return hls
end

---Renders the div into a string.
---@return string
function Div:to_string()
  local pieces = {}
  ---@param div Div
  local function go(div)
    table.insert(pieces, div.text)
    local size = #div.text
    for _, child in ipairs(div.divs) do
      go(child)
      size = size + child._size
    end
    div._size = size
  end
  go(self)
  return table.concat(pieces)
end

---Returns true if the div renders into the empty string.
---@return boolean
function Div:is_empty()
  return #self:to_string() == 0
end

---Represents a node in a path through a div.
---@class PathNode
---@field idx number @the index in the current div's children to follow
---@field name string @the name that the indexed child should have
---@field offset number|nil @if provided, a byte offset from the beginning of this div

---Get the raw byte position of the div arrived at by following the given path.
---@param path PathNode[] @the path to follow
---@return number|nil @the position if the path was valid, nil otherwise
---@return number|nil @the additional byte offset from the position if the path was valid, nil otherwise
function Div:pos_from_path(path)
  local pos = 1
  for i, p in ipairs(path) do
    if i == 1 then -- first path node encodes root
      if p.name ~= self.name then return nil end
    else
      if #self.divs < p.idx then return nil end
      pos = pos + #self.text
      for j = 1, p.idx - 1 do pos = pos + self.divs[j]._size end
      self = self.divs[p.idx]
    end
  end
  local offset = path[#path].offset or 0
  -- in case this is an invalid or outdated path
  offset = (#self.text - 1 >= offset) and offset
  offset = offset or 0
  return pos, offset
end

---Get the div stack and div arrived at by following the given path.
---@param path PathNode[] @the path to follow
---@return Div[]|nil @the stack of divs at this path, or nil if the path is invalid
---@return Div|nil @the div at this path, or nil if the path is invalid
function Div:div_from_path(path)
  local stack = { self }
  for i, p in ipairs(path) do
    if i == 1 then -- first path node encodes root
      if p.name ~= self.name then return nil, nil end
    else
      if #self.divs < p.idx then return nil, nil end
      self = self.divs[p.idx]
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

-- Finds the innermost div satisfying a predicate
---@param path PathNode[]
---@param check fun(div:Div):boolean
---@return Div @The div satisfying check
---@return Div[] @The div stack up to and including that div
---@return PathNode[] @The subpath up to that div
function Div:find_innermost_along(path, check)
  local stack, _ = self:div_from_path(path)
  if stack == nil then return end

  for i = #stack, 1, -1 do
    local this_div = stack[i]
    if check(this_div) then
      return this_div, take(stack, i), take(path, i)
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
---(requires previous call to Div:to_string)
---@param pos integer byte position
---@return PathNode[]|nil the path at this position
---@return Div[]|nil the stack of divs along this path
function Div:path_from_pos(pos)
  local path = { { idx = 0, name = self.name } }
  local stack = { self }
  pos = pos - 1
::next::
  if pos < #self.text then
    path[#path].offset = pos
    return path, stack
  end
  pos = pos - #self.text
  for idx, child in ipairs(self.divs) do
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

---@class DivEventContext
---@field rerender fun()
---@field rehover fun()
---@field self BufDiv

---Trigger the given event at the given path
---@param path PathNode[] @the path to trigger the event at
---@param event_name string @the path to trigger the event at
function Div:event(path, event_name, ...)
  local event_div = self:find_innermost_along(path,
    ---@param div Div
    function (div) return div.events and div.events[event_name] end)
  if not event_div then
    return false
  end

  local args = {...}

  async.void(function()
    return event_div.events[event_name](unpack(args))
  end)()
  return true
end

---Returns true if check is true for one of the descendants
---@param check fun(div:Div):boolean
function Div:find(check)
  if check(self) then return self end

  for _, div in pairs(self.divs) do
    local found = div:find(check)
    if found then return found end
  end
end

function Div:__filter(path, pos, fn)
  pos = pos + #self.text

  for idx, child in ipairs(self.divs) do
    local new_path = {unpack(path)}
    table.insert(new_path, {idx = idx, name = child.name})
    fn(child, new_path, pos)

    pos = child:__filter(new_path, pos, fn)
  end

  return pos
end

function Div:filter(fn)
  local path = {{idx = -1, name = self.name}}
  local pos = 1
  fn(self, path, pos)

  self:__filter(path, pos, fn)
end

-- Creates an impotent deep copy of this div (both tag-stripped and event-disabled).
function Div:dummy_copy()
  local dummy = Div:new(self.text, self.name, self.hlgroup)
  dummy.highlightable = self.highlightable
  for _, child in ipairs(self.divs) do
    table.insert(dummy.divs, child:dummy_copy())
  end
  if self.tooltip then
    dummy.tooltip = self.tooltip:dummy_copy()
  end
  return dummy
end

---@param divs Div[]
---@param sep string
local function concat(divs, sep)
  local out = Div:new()
  for i, d in ipairs(divs) do
    if i > 1 then out:insert_div(sep) end
    out:add_div(d)
  end
  return out
end

---Utility for rendering a div with a particular buffer.
---@class BufDiv
---@field buf integer Buffer number of the buffer the div renders to
---@field div Div Div rendered by this buffer
---@field lines? string[] Rendered lines.
---@field path? PathNode[] Current cursor path
---@field last_win? integer Window number of the last event
---@field keymaps table Extra keymaps (inherited by tooltips)
---@field hover_range? integer[][] (0,0)-range of the highlighted node
---@field tooltip? BufDiv currently open tooltip
---@field parent? BufDiv Parent bufdiv
---@field parent_path? PathNode[] Path in parent div, events bubble up to the parent there
local BufDiv = {}
BufDiv.__index = BufDiv

-- Maps BufDiv.buf to BufDiv
--- @type table<number, BufDiv>
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

---@param buf number
---@param div Div
---@param keymaps? table Extra keymaps
function BufDiv:new(buf, div, keymaps)
  gc()

  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  local new_bufdiv = setmetatable({
    buf = buf,
    keymaps = keymaps,
    div = div,
  }, self)
  self = new_bufdiv
  _by_buf[buf] = self

  util.set_augroup("DivPosition", string.format([[
    autocmd CursorMoved <buffer=%d> lua require'lean.html'._by_buf[%d]:buf_update_cursor()
    autocmd BufEnter <buffer=%d> lua require'lean.html'._by_buf[%d]:buf_update_cursor()
  ]], buf, buf, buf, buf), buf)

  local mappings = {n = {}}
  if keymaps then
    for key, event in pairs(keymaps) do
      mappings.n[key] = ([[<Cmd>lua require'lean.html'._by_buf[%d]:buf_event("%s")<CR>]]):format(buf, event)
    end
    mappings.n["<Tab>"] = ([[<Cmd>lua require'lean.html'._by_buf[%d]:buf_enter_tooltip()<CR>]]):format(buf)
    mappings.n["<S-Tab>"] = (
      [[<Cmd>lua require'lean.html'._by_buf[%d]:buf_goto_parent_tooltip()<CR>]]
    ):format(buf)
    mappings.n["J"] = ([[<Cmd>lua require'lean.html'._by_buf[%d]:buf_enter_tooltip()<CR>]]):format(buf)
    mappings.n["S"] = ([[<Cmd>lua require'lean.html'._by_buf[%d]:buf_hop_to()<CR>]]):format(buf)
  end
  util.load_mappings(mappings, buf)

  return new_bufdiv
end

---@param keep_tooltips_open? boolean
function BufDiv:buf_close(keep_tooltips_open)
  if vim.api.nvim_buf_is_valid(self.buf) then
    vim.api.nvim_buf_delete(self.buf, {force = true})
    gc()
  end
  if self.tooltip then
    self.tooltip.parent = nil
    self.tooltip.parent_path = nil
    if not keep_tooltips_open then
      self.tooltip:buf_close()
      self.tooltip = nil
    end
  end
end

local div_ns = vim.api.nvim_create_namespace("LeanNvimInfo")
local hl_ns = vim.api.nvim_create_namespace('LeanNvimInfoHighlight')

function BufDiv:buf_render()
  local buf = self.buf

  if not vim.api.nvim_buf_is_valid(buf) then return end

  vim.api.nvim_buf_clear_namespace(buf, div_ns, 0, -1)

  local text = self.div:to_string()
  local lines = vim.split(text, '\n')
  self.lines = lines

  local hls = self.div:_get_highlights()

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
    vim.highlight.range(buf, div_ns, hl.hlgroup, start_pos, end_pos)
  end

  if self.path then
    -- on a rerender any previously existing paths may be invalid
    -- TODO: cache div_from_path() return value to use in buf_hover
    if not self.div:div_from_path(self.path) then
      self.path = nil
    elseif self:buf_last_win_valid() then
      local raw_pos, offset = self.div:pos_from_path(self.path)
      local pos = raw_pos_to_pos(raw_pos + offset, lines)
      pos[1] = pos[1] + 1
      vim.api.nvim_win_set_cursor(self.last_win, pos)
    end
  end

  self:buf_hover(true)
end

function BufDiv:buf_enter_tooltip()
  if self.tooltip and self.tooltip:buf_last_win_valid() then
    vim.api.nvim_set_current_win(self.tooltip.last_win)
  end
end

function BufDiv:buf_goto_parent_tooltip()
  if self.parent and self.parent:buf_last_win_valid() then
    vim.api.nvim_set_current_win(self.parent.last_win)
  end
end

function BufDiv:buf_last_win_valid()
  return self.last_win
    and vim.api.nvim_win_is_valid(self.last_win)
    and vim.api.nvim_win_get_buf(self.last_win) == self.buf
end

function BufDiv:buf_update_cursor(win)
  if self.disable_update then return end
  win = win or vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) == self.buf then
    self.last_win = win
  end
  if not self:buf_last_win_valid() then return end

  local path_changed = self:buf_update_position()

  if path_changed then
    self:buf_hover()
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

function BufDiv:buf_update_position()
  local path_before = self.path
  local cursor_pos = vim.api.nvim_win_get_cursor(self.last_win)
  local raw_pos = pos_to_raw_pos(cursor_pos, self.lines)
  if not raw_pos then return end

  self.path = self.div:path_from_pos(raw_pos)

  if not path_equal(path_before, self.path) then
    self:buf_event("cursor_leave", path_before)
    self:buf_event("cursor_enter", self.path)
    return true
  end

  return false
end

function BufDiv:buf_hover(force_update_highlight)
  local path = self.path

  local old_hover_range = self.hover_range

  if not path then
    if self.tooltip ~= nil then
      self.tooltip:buf_close()
      self.tooltip = nil
    end
    vim.api.nvim_buf_clear_namespace(self.buf, hl_ns, 0, -1)
    self.hover_range = nil
    return
  end

  local hover_div, _, hover_div_path = self.div:find_innermost_along(path,
    ---@param div Div
    function (div) return div.highlightable end)

  local tt_parent_div, _, tt_parent_div_path = self.div:find_innermost_along(path,
    ---@param div Div
    function (div) return div.tooltip end)

  local new_tooltip_div = tt_parent_div and tt_parent_div.tooltip

  if self.tooltip ~= nil and new_tooltip_div == nil then
    self.tooltip:buf_close()
    self.tooltip = nil
  end

  if new_tooltip_div ~= nil then
    local width, height = util.make_floating_popup_size(vim.split(new_tooltip_div:to_string(), "\n"))

    local tt_parent_path = tt_parent_div_path
    local bufpos = raw_pos_to_pos(self.div:pos_from_path(tt_parent_path), self.lines)

    if self.tooltip then -- reuse old tooltip window
      self.tooltip.div = new_tooltip_div
    else
      local bufnr = vim.api.nvim_create_buf(false, true)
      self.tooltip = BufDiv:new(bufnr, new_tooltip_div, self.keymaps)
      vim.api.nvim_buf_set_option(self.tooltip.buf, "bufhidden", "wipe")
    end

    self.tooltip.parent = self
    self.tooltip.parent_path = tt_parent_div_path

    local tooltip_buf = self.tooltip.buf

    local win_options = {
      relative = "win",
      win = self.last_win,
      style = "minimal",
      width = width,
      height = height,
      border = "none",
      bufpos = bufpos,
      zindex = 50 + tooltip_buf -- later tooltips are guaranteed to have greater buffer handles
    }

    if not self.tooltip:buf_last_win_valid() then
      -- fresh non-reused tooltip, open window
      self.tooltip.disable_update = true
      self.tooltip.last_win = vim.api.nvim_open_win(tooltip_buf, false, win_options)
      self.tooltip.disable_update = false
      -- workaround for neovim/neovim#13403, as it seems this wasn't entirely resolved by neovim/neovim#14770
      vim.api.nvim_command("redraw")
      self.tooltip.last_win_options = vim.deepcopy(win_options)
    elseif not vim.deep_equal(win_options, self.tooltip.last_win_options) then
      vim.api.nvim_win_set_config(self.tooltip.last_win, win_options)
      vim.api.nvim_command("redraw")
      self.tooltip.last_win_options = vim.deepcopy(win_options)
    end

    self.tooltip:buf_render()
  end

  if hover_div_path and hover_div then
    local a = self.div:pos_from_path(hover_div_path)
    local start_pos = raw_pos_to_pos(a, self.lines)
    local end_pos = raw_pos_to_pos(a + hover_div._size, self.lines)
    self.hover_range = {start_pos, end_pos}
  else
    self.hover_range = nil
  end

  if force_update_highlight or not vim.deep_equal(old_hover_range, self.hover_range) then
    vim.api.nvim_buf_clear_namespace(self.buf, hl_ns, 0, -1)
    local hlgroup = "htmlDivHighlight"
    if self.hover_range then
      vim.highlight.range(self.buf, hl_ns, hlgroup, self.hover_range[1], self.hover_range[2])
    end
  end
end

function BufDiv:buf_event(event, path, ...)
  local args = {...}

  path = path or self.path

  if not path then return end

  if not self.div:event(path, event, self:buf_make_event_context(), unpack(args)) and self.parent then
    -- bubble up to parent
    return self.parent:buf_event(event, self.parent_path, ...)
  end
end

---@return DivEventContext
function BufDiv:buf_make_event_context()
  return {
    rerender = function() self:buf_render() end,
    rehover = function() self:buf_hover() end,
    self = self,
  }
end

function BufDiv:buf_enter_win()
  local deepest_tooltip = self:buf_get_deepest_tooltip()
  if deepest_tooltip:buf_last_win_valid() then
    vim.api.nvim_set_current_win(deepest_tooltip.last_win)
  end
end

function BufDiv:buf_get_deepest_tooltip()
  while self.tooltip do
    self = self.tooltip
  end
  return self
end

function BufDiv:buf_hop_to()
  while self.parent do
    self = self.parent
  end
  self:buf_hop(function(div) return div.highlightable end, require"hop.hint_util".callbacks.win_goto)
end

function BufDiv:buf_hop(filter_fn, callback_fn)
  local winpos = vim.api.nvim_win_get_position(0)
  local strategy = {
    get_hint_list = function()
      local hints = {}
      local windows = {}

      ---@param root BufDiv
      local function buf_get_hints(root)
        local this_buf = root.buf
        local this_win = root.last_win
        if not this_win then return end
        table.insert(windows, this_win)
        local lines = root.lines
        local window_dist = require"hop.hint_util".manh_dist(winpos, vim.api.nvim_win_get_position(this_win))

        root.div:filter(function(div, _, raw_pos)
          if not filter_fn(div) then return end
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

          -- prevent duplicate hints; this works because we are pre-order traversing the div tree
          if not vim.deep_equal(hint, hints[#hints]) then
            table.insert(hints, hint)
          end
        end)

        if root.tooltip then
          buf_get_hints(root.tooltip)
        end
      end

      buf_get_hints(self)

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

return {Div = Div, BufDiv = BufDiv, util = {
  pos_to_raw_pos = pos_to_raw_pos,
  raw_pos_to_pos = raw_pos_to_pos,
}, _by_buf = _by_buf, concat = concat}
