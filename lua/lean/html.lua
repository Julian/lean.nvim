--- An HTML-style div
---@class Div
---@field tags table
---@field text string
---@field name string
---@field hlgroup string
---@field divs table
---@field div_stack table
local Div = {}
Div.__index = Div

function Div:new(tags, text, name, hlgroup)
  return setmetatable({tags = tags or {}, text = text or "", name = name or "", hlgroup = hlgroup,
    divs = {}, div_stack = {}}, self)
end

function Div:add_div(div)
  table.insert(self.divs, div)
  return div
end

function Div:insert_new_div(new_div)
  local last_div = self.div_stack[#self.div_stack]
  if last_div then
    return last_div:add_div(new_div)
  else
    return self:add_div(new_div)
  end
end

function Div:start_div(tags, text, name, hlgroup)
  local new_div = Div:new(tags, text, name, hlgroup)
  self:insert_new_div(new_div)
  table.insert(self.div_stack, new_div)
  return new_div
end

function Div:end_div()
  table.remove(self.div_stack)
end

function Div:insert_div(tags, text, name, hlgroup)
  local new_div = self:start_div(tags, text, name, hlgroup)
  self:end_div()
  return new_div
end

function Div:render()
  local text = self.text
  local hls = {}
  for _, div in ipairs(self.divs) do
    local new_text, new_hls = div:render()
    for _, new_hl in ipairs(new_hls) do
      new_hl.start = new_hl.start + #text
      new_hl["end"] = new_hl["end"] + #text
    end
    vim.list_extend(hls, new_hls)
    text = text .. new_text
  end
  if self.hlgroup then
    local hlgroup = self.hlgroup
    if type(hlgroup) == "function" then
      hlgroup = hlgroup(self)
    end

    if hlgroup then
      table.insert(hls, {start = 1, ["end"] = #text, hlgroup = hlgroup})
    end
  end
  return text, hls
end

function Div:_pos_from_div(div)
  local text = self.text

  -- base case
  if self == div then return nil, 1, {} end

  local pos = #text

  for idx, this_div in ipairs(self.divs) do
    local div_text, div_pos, div_path = this_div:_pos_from_div(div)
    if div_pos then
      table.insert(div_path, {idx = idx, name = this_div.name})
      return nil, pos + div_pos, div_path
    end
    text = text .. div_text
    pos = #text
  end

  return text, nil, nil
end

function Div:pos_from_div(div)
  local _, pos, path = self:_pos_from_div(div)
  if path then table.insert(path, {idx = -1, name = self.name}) end
  return pos, path
end

function Div:_div_from_path(path)
  if #path == 0 then return self end
  path = {unpack(path)}

  local this_branch = table.remove(path)
  local this_div = self.divs[this_branch.idx]
  local this_name = this_branch.name

  if not this_div or this_div.name ~= this_name then return nil end

  return this_div:_div_from_path(path)
end

function Div:div_from_path(path)
  path = {unpack(path)}

  -- check that the first name matches
  if self.name ~= table.remove(path).name then return nil end

  return self:_div_from_path(path)
end

function Div:_div_from_pos(pos, stack)
  stack = stack or {}
  table.insert(stack, self)

  local text = self.text

  -- base case
  if pos <= #text then return nil, stack end

  local search_pos = pos - #text

  for _, div in ipairs(self.divs) do
    local div_text, div_stack = div:_div_from_pos(search_pos, stack)
    if div_stack then
      return nil, div_stack
    end
    text = text .. div_text
    search_pos = search_pos - #div_text
  end

  table.remove(stack)
  return text, nil
end

function Div:div_from_pos(pos, stack)
  local _, div_stack = self:_div_from_pos(pos, stack)
  return div_stack
end

local function _get_parent_div(div_stack, check)
  for i = #div_stack, 1, -1 do
    local this_div = div_stack[i]
    if check(this_div) then
      return this_div
    end
  end
end

local function get_parent_div(div_stack, check)
  if type(check) == "string" then
    return _get_parent_div(div_stack, function(div) return div.name == check end)
  end
  return _get_parent_div(div_stack, check)
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

local function raw_pos_to_pos(raw_pos, lines)
  local line_num = 0
  local rem_chars = raw_pos

  for _, line in ipairs(lines) do
    line_num = line_num + 1
    if rem_chars <= (#line + 1) then break end

    rem_chars = rem_chars - (#line + 1)
  end

  return {line_num - 1, rem_chars - 1}
end

function Div:render_buf(bufnr, ns)
  local text, hls = self:render()
  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)

  table.sort(hls, function(hl1, hl2)
    local range1 = (hl1["end"] - hl1.start)
    local range2 = (hl2["end"] - hl2.start)
    if range1 > range2 then
      return true
    elseif range1 == range2 then
      -- clickable highlight takes priority
      return hl2.hlgroup == "leanInfoHighlight"
    else
      return false
    end
  end)

  for _, hl in ipairs(hls) do
    local start_pos = raw_pos_to_pos(hl.start, lines)
    local end_pos = raw_pos_to_pos(hl["end"], lines)
    vim.highlight.range(
      bufnr,
      ns,
      hl.hlgroup,
      start_pos,
      {end_pos[1], end_pos[2] + 1}
    )
  end
end

local function buf_get_parent_div(pos, bufnr, div, check)
  local raw_pos = pos_to_raw_pos(pos, vim.api.nvim_buf_get_lines(bufnr, 0, -1, true))
  if not raw_pos then return end

  local div_stack = div:div_from_pos(raw_pos)
  if not div_stack then return end

  return get_parent_div(div_stack, check), div_stack
end

local function is_event_div_check(eventName)
  return function (div)
    if not div.tags.event then return false end
    local event = div.tags.event[eventName]
    if event then return true end
    return false
  end
end

function Div:event(pos, eventName, ...)
  local div_stack = self:div_from_pos(pos)
  if not div_stack then return end

  local event_div = get_parent_div(div_stack, is_event_div_check(eventName))

  if event_div then event_div.tags.event[eventName](...) end
end

function Div:hover(pos, check)
  local div_stack = self:div_from_pos(pos)
  if not div_stack then return end

  local hover_div = get_parent_div(div_stack, check)

  if hover_div == self.prev_hover_div then return end

  if hover_div then
    hover_div.tags.__highlight = true
  end

  if self.prev_hover_div then
    self.prev_hover_div.tags.__highlight = false
  end

  self.prev_hover_div = hover_div
end

function Div:filter(fn)
  fn(self)

  for _, div in pairs(self.divs) do
    div:filter(fn)
  end
end

return {Div = Div, util = { get_parent_div = get_parent_div,
pos_to_raw_pos = pos_to_raw_pos, raw_pos_to_pos = raw_pos_to_pos,
buf_get_parent_div = buf_get_parent_div, is_event_div_check = is_event_div_check,
highlight_check = function(div)
  return div.tags.__highlight and "leanInfoHighlight"
end}}
