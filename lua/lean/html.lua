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
end

function Div:start_div(tags, text, name, hlgroup)
  local new_div = Div:new(tags, text, name, hlgroup)
  local last_div = self.div_stack[#self.div_stack]
  if last_div then
    last_div:add_div(new_div)
  else
    self:add_div(new_div)
  end
  table.insert(self.div_stack, new_div)
end

function Div:end_div()
  table.remove(self.div_stack)
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
  if self.hlgroup then table.insert(hls, {start = 1, ["end"] = #text, hlgroup = self.hlgroup}) end
  return text, hls
end

function Div:div_from_pos(pos, stack)
  stack = stack or {}
  table.insert(stack, self)

  local text = self.text

  -- base case
  if pos <= #text then return nil, stack end

  local search_pos = pos - #text

  for _, div in ipairs(self.divs) do
    local div_text, div_stack = div:div_from_pos(search_pos, stack)
    if div_stack then
      return nil, div_stack
    end
    text = text .. div_text
    search_pos = search_pos - #div_text
  end

  table.remove(stack)
  return text, nil
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
  if not lines[pos[1]] or pos[2] + 1 > #lines[pos[1]] then return end
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

local function buf_get_parent_div(pos, bufnr, div, check)
  local raw_pos = pos_to_raw_pos(pos, vim.api.nvim_buf_get_lines(bufnr, 0, -1, true))
  if not raw_pos then return end

  local _, div_stack = div:div_from_pos(raw_pos)
  if not div_stack then return end

  return get_parent_div(div_stack, check), div_stack
end

return {Div = Div, util = { get_parent_div = get_parent_div,
pos_to_raw_pos = pos_to_raw_pos, raw_pos_to_pos = raw_pos_to_pos, buf_get_parent_div = buf_get_parent_div }}
