local position_to_byte0 = require('std.lsp').position_to_byte0

local Element = require('lean.tui').Element

local hl_ns = vim.api.nvim_create_namespace 'proofwidgets.make_edit_link'

---@class MakeEditLinkProps
---@field edit lsp.TextDocumentEdit The edit to perform on the file.
---@field newSelection? lsp.Range Which textual range to select after the edit.
---                               The range is interpreted in the file that `edit` applies to.
---                               If present and `start == end`, the cursor is moved to `start`
---                               and nothing is selected.
---                               If not present, the selection is not changed.
---@field title? string

---@param props MakeEditLinkProps
---@param children Element[]
---@param ctx RenderContext
return function(props, children, ctx)
  return Element:new {
    children = children,
    highlightable = true,
    hlgroup = 'widgetLink',
    events = {
      click = function()
        local bufnr = vim.uri_to_bufnr(props.edit.textDocument.uri)
        if not vim.api.nvim_buf_is_loaded(bufnr) then
          return
        end
        vim.lsp.util.apply_text_document_edit(props.edit, nil, 'utf-16')
        if props.newSelection then
          local start = position_to_byte0(props.newSelection.start, bufnr)
          local end_ = position_to_byte0(props.newSelection['end'], bufnr)

          if not vim.deep_equal(props.newSelection.start, props.newSelection['end']) then
            vim.hl.range(bufnr, hl_ns, 'widgetChangedText', start, end_, { timeout = 1000 })
          end

          local last_window = ctx.get_last_window()
          if not last_window then
            return
          end
          last_window:make_current()
          last_window:set_cursor { end_[1] + 1, end_[2] }
        end
      end,
    },
  }
end
