---@brief [[
--- An import graph widget that allows jumping to a module.
---@brief ]]

local Element = require('lean.tui').Element
local log = require 'lean.log'

---@class GoToModuleLinkParams
---@field modName string the module to jump to

---A "jump to a module" widget defined in `ImportGraph`.
---@param ctx RenderContext
---@param props GoToModuleLinkParams
return function(ctx, props)
  return Element.link {
    text = props.modName,
    events = {
      go_to_def = function(_)
        local last_window = ctx.get_last_window()
        if not last_window then
          return
        end
        last_window:make_current()
        local uri, err = ctx:rpc_call('ImportGraph.Widget.getModuleUri', props.modName)
        if err then
          vim.schedule(function()
            log:error {
              message = 'GoToModule error',
              err = err,
              props = props,
            }
          end)
          return
        end
        ---@type lsp.Position
        local start = { line = 0, character = 0 }
        vim.lsp.util.show_document(
          { uri = uri, range = { start = start, ['end'] = start } },
          'utf-16',
          { focus = true }
        )
      end,
    },
  }
end
