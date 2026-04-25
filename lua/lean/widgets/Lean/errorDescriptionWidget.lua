local Element = require('lean.tui').Element

---@alias ErrorDescription { code: string, explanationUrl: string }

---@param ctx RenderContext
---@param props ErrorDescription
return function(_, props)
  return Element:new {
    children = {
      Element.text '\n\nError code: ',
      Element.text(props.code),
      Element.text '\n',
      Element.link {
        text = 'View explanation',
        action = function()
          vim.ui.open(props.explanationUrl)
        end,
      },
    },
  }
end
