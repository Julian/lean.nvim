local Element = require('lean.tui').Element

---@class GoToModuleLinkParams
---@field modName string the module to jump to

---A "jump to a module" widget defined in `ImportGraph`.
---@param ctx RenderContext
---@param props GoToModuleLinkParams
return function(ctx, props)
  return Element:new {
    text = props.modName,
    highlightable = true,
    hlgroup = 'widgetLink',
    events = {
      go_to_def = function(_)
        local last_window = ctx.get_last_window()
        if not last_window then
          return
        end
        vim.api.nvim_set_current_win(last_window)
        local uri, err = ctx:rpc_call('getModuleUri', props.modName)
        if err then
          return -- FIXME: Yeah, this should go somewhere clearly.
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
