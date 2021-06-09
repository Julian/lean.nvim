local M = { handlers = {} }

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

function M.handlers.plain_goal_handler (_, method, result, _, _, config)
  config = config or {}
  config.focus_id = method
  if not (result and result.rendered) then
    return
  end
  local markdown_lines = vim.lsp.util.convert_input_to_markdown_lines(result.rendered)
  markdown_lines = vim.lsp.util.trim_empty_lines(markdown_lines)
  if vim.tbl_isempty(markdown_lines) then
    return
  end
  return vim.lsp.util.open_floating_preview(markdown_lines, "markdown", config)
end

return M
