local M = { handlers = {} }

function M.enable3(opts)
  require('lspconfig').lean3ls.setup(opts)
end

function M.enable(opts)
  opts.commands = vim.tbl_extend("keep", opts.commands or {}, {
    LeanPlainGoal = {
      function ()
        local params = vim.lsp.util.make_position_params()
        -- Shift forward by 1, since in vim it's easier to reach word
        -- boundaries in normal mode.
        params.position.character = params.position.character + 1
        vim.lsp.buf_request(0, "$/lean/plainGoal", params)
      end;
      description = "Describe the current tactic state."
    };
  })
  opts.handlers = vim.tbl_extend("keep", opts.handlers or {}, {
    ["$/lean/plainGoal"] = M.handlers.plain_goal_handler;
  })
  require('lspconfig').leanls.setup(opts)
end

function M.handlers.plain_goal_handler (_, method, result)
  vim.lsp.util.focusable_float(method, function()
    if not (result and result.rendered) then
      return
    end
    local markdown_lines = vim.lsp.util.convert_input_to_markdown_lines(result.rendered)
    markdown_lines = vim.lsp.util.trim_empty_lines(markdown_lines)
    if vim.tbl_isempty(markdown_lines) then
      return
    end
    local bufnr, winnr = vim.lsp.util.fancy_floating_markdown(markdown_lines, {
      pad_left = 1; pad_right = 1;
    })
    vim.lsp.util.close_preview_autocmd({"CursorMoved", "BufHidden", "InsertCharPre"}, winnr)
    return bufnr, winnr
  end)
end

return M
