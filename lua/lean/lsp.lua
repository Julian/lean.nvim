local ms = vim.lsp.protocol.Methods

local lsp = { handlers = {} }
local util = require 'lean._util'

function lsp.enable(opts)
  opts.handlers = vim.tbl_extend('keep', opts.handlers or {}, {
    ['$/lean/fileProgress'] = lsp.handlers.file_progress_handler,
    ['textDocument/publishDiagnostics'] = function(...)
      lsp.handlers.diagnostics_handler(...)
      vim.lsp.handlers['textDocument/publishDiagnostics'](...)
    end,
  })
  opts.init_options = vim.tbl_extend('keep', opts.init_options or {}, {
    editDelay = 0, -- see #289
    hasWidgets = true,
  })
  require('lspconfig').leanls.setup(opts)
end

--- Find the vim.lsp.Client attached to the given buffer.
---@param bufnr number
---@return vim.lsp.Client
function lsp.client_for(bufnr)
  local clients = vim.lsp.get_clients { name = 'leanls', bufnr = bufnr }
  return clients[1]
end

-- Fetch goal state information from the server (async).
---@param params lsp.TextDocumentPositionParams
---@param bufnr number
---@return any error
---@return any plain_goal
function lsp.plain_goal(params, bufnr)
  local client = lsp.client_for(bufnr)
  if not client then
    return 'LSP server not connected', nil
  end

  params = vim.deepcopy(params)
  -- Shift forward by 1, since in vim it's easier to reach word
  -- boundaries in normal mode.
  params.position.character = params.position.character + 1
  return util.client_a_request(client, '$/lean/plainGoal', params)
end

-- Fetch term goal state information from the server (async).
---@param params lsp.TextDocumentPositionParams
---@param bufnr number
---@return any error
---@return any plain_term_goal
function lsp.plain_term_goal(params, bufnr)
  local client = lsp.client_for(bufnr)
  if not client then
    return 'LSP server not connected', nil
  end
  return util.client_a_request(client, '$/lean/plainTermGoal', params)
end

function lsp.handlers.file_progress_handler(err, params)
  if err ~= nil then
    return
  end

  require('lean.progress').update(params)

  require('lean.infoview').__update_pin_by_uri(params.textDocument.uri)

  require('lean.progress_bars').update(params)
end

function lsp.handlers.diagnostics_handler(_, params)
  -- Make sure there are no zero-length diagnostics.
  for _, diag in pairs(params.diagnostics) do
    ---@type lsp.Range
    local range = diag.range
    if
      range.start.line == range['end'].line and range.start.character == range['end'].character
    then
      range['end'].character = range.start.character + 1
    end
  end

  -- XXX: Why does this now sometimes fail?!
  --      The pcall was introduced as part of user widgets; removing it
  --      should make some tests fail, but tests relating to infoview widgets
  --      (i.e. not user widgets), and fail with cryptic errors, either about
  --      nvim_buf_set_lines emitting a E1510: Value too large with no info
  --      or (on nightly neovim) some other equally cryptic nested failure.
  --      Putting the pcall here rather than on the nvim_buf_set_lines line
  --      since it's during diagnostic updates that it seems to blow up?
  pcall(require('lean.infoview').__update_pin_by_uri, params.uri)
end

---Restart the Lean server for an open Lean 4 file.
---See e.g. https://github.com/leanprover/lean4/blob/master/src/Lean/Server/README.md#recompilation-of-opened-files
---@param bufnr? number
function lsp.restart_file(bufnr)
  bufnr = bufnr or 0
  local client = lsp.client_for(bufnr)
  local uri = vim.uri_from_bufnr(bufnr)

  client.notify(ms.textDocument_didClose, { textDocument = { uri = uri } })
  client.notify(ms.textDocument_didOpen, {
    textDocument = {
      version = 0,
      uri = uri,
      languageId = 'lean',
      text = util.buf_get_full_text(bufnr),
    },
  })
end

return lsp
