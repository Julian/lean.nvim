--- An HTML-style div
---@class Div
---@field tags table
---@field text string
---@field name string
---@field divs table
---@field div_stack table
local Div = {}
Div.__index = Div

function Div:new(tags, text, name)
  return setmetatable({tags = tags or {}, text = text or "", name = name or "", divs = {}, div_stack = {}}, self)
end

function Div:add_div(div)
  table.insert(self.divs, div)
end

function Div:start_div(tags, text, name)
  local new_div = Div:new(tags, text, name)
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
  for _, div in ipairs(self.divs) do
    text = text .. div:render()
  end
  return text
end

function Div:div_from_pos(pos, stack)
  stack = stack or {}
  local new_stack = vim.fn.copy(stack)
  table.insert(new_stack, self)

  local text = self.text

  -- base case
  if pos <= #text then return nil, new_stack end

  local search_pos = pos - #text

  for _, div in ipairs(self.divs) do
    local div_text, div_stack = div:div_from_pos(search_pos, new_stack)
    if div_stack then
      return nil, div_stack
    end
    text = text .. div_text
    search_pos = search_pos - #div_text
  end

  return text, nil
end

return {Div = Div}
