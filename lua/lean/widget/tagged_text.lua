local inductive = require 'std.inductive'

local Element = require('lean.tui').Element

---@generic T
---@class TaggedText<T>

---The minimal structure needed to represent "string with interesting (tagged) substrings".
---@generic T
---@param tag_type_name string
---@param tag_type T
local function TaggedText(tag_type_name, tag_type)
  return inductive(('TaggedText<%s>'):format(tag_type_name), {
    text = function(_, text)
      return Element:new { text = text }
    end,

    append = function(self, append, ...)
      local args = { ... }
      return Element:new {
        children = vim
          .iter(append)
          :map(function(each)
            return self(each, unpack(args))
          end)
          :totable(),
      }
    end,

    ---@generic T
    ---@param tag { [1]: T, [2]: TaggedText<T> }
    tag = function(_, tag, ...)
      return tag_type(tag[1], tag[2], ...)
    end,
  })
end

return TaggedText
