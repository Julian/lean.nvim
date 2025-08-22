local Element = require('lean.tui').Element

---@alias ErrorDescription { code: string, explanationUrl: string }

---@param ctx RenderContext
---@param props ErrorDescription
return function(_, props)
  return Element:new {
    children = {
      Element:new { text = '\n\nError code: ' },
      Element:new { text = props.code },
      Element:new { text = '\n' },
      Element:new {
        text = 'View explanation',
        highlightable = true,
        hlgroup = 'widgetLink',
        events = {
          click = function()
            vim.ui.open(props.explanationUrl)
          end,
        },
      },
    },
  }
end
