local lsp = { handlers = {} }

function lsp.enable(opts)
  opts.commands = vim.tbl_extend("keep", opts.commands or {}, {
    LeanPlainGoal = {
      lsp.plain_goal;
      description = "Describe the current tactic state."
    };
    LeanPlainTermGoal = {
      lsp.plain_term_goal;
      description = "Describe the expected type of the current term."
    };
  })
  opts.handlers = vim.tbl_extend("keep", opts.handlers or {}, {
    ["$/lean/plainGoal"] = lsp.handlers.plain_goal_handler;
    ["$/lean/plainTermGoal"] = lsp.handlers.plain_term_goal_handler;
  })
  require('lspconfig').leanls.setup(opts)
end

-- Fetch goal state information from the server.
function lsp.plain_goal(bufnr, handler, buf_request)
  buf_request = buf_request or vim.lsp.buf_request
  -- Shift forward by 1, since in vim it's easier to reach word
  -- boundaries in normal mode.
  local params = vim.lsp.util.make_position_params()
  params.position.character = params.position.character + 1
  return buf_request(bufnr, "$/lean/plainGoal", params, handler)
end

-- Fetch term goal state information from the server.
function lsp.plain_term_goal(bufnr, handler, buf_request)
  buf_request = buf_request or vim.lsp.buf_request
  local params = vim.lsp.util.make_position_params()
  return buf_request(bufnr, "$/lean/plainTermGoal", params, handler)
end

function lsp.handlers.plain_goal_handler (_, method, result, _, _, config)
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

function lsp.handlers.plain_term_goal_handler (_, method, result, _, _, config)
  config = config or {}
  config.focus_id = method
  if not (result and result.goal) then
    return
  end
  return vim.lsp.util.open_floating_preview(
    vim.split(result.goal, '\n'), "leaninfo", config
  )
end

return lsp
