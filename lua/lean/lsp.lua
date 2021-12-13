local lsp = { handlers = {} }
local util = require"lean._util"

function lsp.enable(opts)
  opts.handlers = vim.tbl_extend("keep", opts.handlers or {}, {
    ["$/lean/plainGoal"] = util.mk_handler(lsp.handlers.plain_goal_handler);
    ["$/lean/plainTermGoal"] = util.mk_handler(lsp.handlers.plain_term_goal_handler);
    ['$/lean/fileProgress'] = util.mk_handler(lsp.handlers.file_progress_handler);
    ['textDocument/publishDiagnostics'] = function(...)
      util.mk_handler(lsp.handlers.diagnostics_handler)(...)
      vim.lsp.handlers['textDocument/publishDiagnostics'](...)
    end;
  })
  if vim.version().major == 0 and vim.version().minor >= 6 then
    -- workaround for https://github.com/neovim/neovim/issues/16624
    opts.flags = vim.tbl_extend('keep', opts.flags or {}, { allow_incremental_sync = false })
  end
  require('lspconfig').leanls.setup(opts)
end

-- Fetch goal state information from the server.
function lsp.plain_goal(params, bufnr, handler)
  params = vim.deepcopy(params)
  -- Shift forward by 1, since in vim it's easier to reach word
  -- boundaries in normal mode.
  params.position.character = params.position.character + 1
  return util.request(bufnr, "$/lean/plainGoal", params, handler)
end

-- Fetch term goal state information from the server.
function lsp.plain_term_goal(params, bufnr, handler)
  params = vim.deepcopy(params)
  return util.request(bufnr, "$/lean/plainTermGoal", params, handler)
end

function lsp.handlers.plain_goal_handler (_, result, ctx, config)
  local method = ctx.method
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

function lsp.handlers.plain_term_goal_handler (_, result, ctx, config)
  local method = ctx.method
  config = config or {}
  config.focus_id = method
  if not (result and result.goal) then
    return
  end
  return vim.lsp.util.open_floating_preview(
    vim.split(result.goal, '\n'), "leaninfo", config
  )
end

function lsp.handlers.file_progress_handler(err, params)
  if err ~= nil then return end

  require"lean.progress".update(params)

  require"lean.infoview".__update_event(params.textDocument.uri)

  require"lean.progress_bars".update(params)
end

function lsp.handlers.diagnostics_handler (_, params)
  -- Make sure there are no zero-length diagnostics.
  for _, diag in pairs(params.diagnostics) do
    ---@type LspRange
    local range = diag.range
    if range.start.line == range['end'].line and range.start.character == range['end'].character then
      range['end'].character = range.start.character + 1
    end
  end

  require"lean.infoview".__update_event(params.uri)
end

return lsp
