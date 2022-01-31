local lsp = { handlers = {} }
local util = require"lean._util"

function lsp.enable(opts)
  opts.handlers = vim.tbl_extend("keep", opts.handlers or {}, {
    ['$/lean/fileProgress'] = util.mk_handler(lsp.handlers.file_progress_handler);
    ['textDocument/publishDiagnostics'] = function(...)
      util.mk_handler(lsp.handlers.diagnostics_handler)(...)
      vim.lsp.handlers['textDocument/publishDiagnostics'](...)
    end;
  })
  opts.init_options = vim.tbl_extend("keep", opts.init_options or {}, {
    hasWidgets = true,
  })
  require('lspconfig').leanls.setup(opts)
end

--- Finds the vim.lsp.client object for the Lean 4 server associated to the
--- given bufnr.
function lsp.get_lean4_server(bufnr)
  local lean_client
  vim.lsp.for_each_buffer_client(bufnr, function (client)
    if client.name == 'leanls' then lean_client = client end
  end)
  return lean_client
end

--- Finds the vim.lsp.client object for the Lean 3 server associated to the
--- given bufnr.
function lsp.get_lean3_server(bufnr)
  local lean_client
  vim.lsp.for_each_buffer_client(bufnr, function (client)
    if client.name == 'lean3ls' then lean_client = client end
  end)
  return lean_client
end

-- Fetch goal state information from the server (async).
---@param params PlainGoalParams
---@param bufnr number
---@return any error
---@return any plain_goal
function lsp.plain_goal(params, bufnr)
  local client = lsp.get_lean4_server(bufnr) or lsp.get_lean3_server(bufnr)
  if not client then return 'LSP server not connected', nil end

  params = vim.deepcopy(params)
  -- Shift forward by 1, since in vim it's easier to reach word
  -- boundaries in normal mode.
  params.position.character = params.position.character + 1
  return util.client_a_request(client, '$/lean/plainGoal', params)
end

-- Fetch term goal state information from the server (async).
---@param params PlainTermGoalParams
---@param bufnr number
---@return any error
---@return any plain_term_goal
function lsp.plain_term_goal(params, bufnr)
  local client = lsp.get_lean4_server(bufnr)
  if not client then return 'LSP server not connected', nil end
  return util.client_a_request(client, '$/lean/plainTermGoal', params)
end

function lsp.handlers.file_progress_handler(err, params)
  if err ~= nil then return end

  require"lean.progress".update(params)

  require"lean.infoview".__update_pin_by_uri(params.textDocument.uri)

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

  require"lean.infoview".__update_pin_by_uri(params.uri)
end

return lsp
