local Element = require('lean.tui').Element
local Html = require 'proofwidgets.html'

---@class FilterDetailsProps
---@field summary Html
---@field filtered Html
---@field all Html
---@field initiallyFiltered boolean

---@param props FilterDetailsProps
---@param ctx RenderContext
---@return Element
return function(props, ctx)
  local is_filtered = props.initiallyFiltered
  return Element:new {
    children = {
      Html(props.summary, ctx),
      Element.select({ true, false }, {
        initial = is_filtered,
        format_item = function(item)
          return item and 'Show more content' or 'Show less content'
        end,
      }, function(choice)
        is_filtered = choice
      end),
      Html(is_filtered and props.filtered or props.all, ctx),
    },
  }
end
