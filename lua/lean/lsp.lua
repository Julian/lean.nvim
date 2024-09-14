local ms = vim.lsp.protocol.Methods

local lsp = { handlers = {} }
local util = require 'lean._util'

---Enable auto-starting the Lean LSP.
---@param opts lean.lsp.Config
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

  vim.g.lean_config.lsp = opts
end

---Attach an LSP client if auto-start is enabled.
---@param bufnr? integer
function lsp.maybe_start(bufnr)
  local config = require 'lean.config'().lsp
  if config == false then
    return
  end
  lsp.start(bufnr, config)
end

---@class lean.lsp.StartConfig: vim.lsp.ClientConfig

---Create a new Lean LSP client and start a language server.
---@param bufnr? integer
---@param client_config? lean.lsp.Config
function lsp.start(bufnr, client_config)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  local root_dir =
    vim.fs.root(bufname, { 'lakefile.toml', 'lakefile.lean', 'lean-toolchain', '.git' })

  ---@type lean.lsp.StartConfig
  local start_config = vim.tbl_deep_extend('keep', { name = 'leanls' }, client_config)
  start_config.cmd = { 'lake', 'serve', '--', root_dir }
  start_config.root_dir = root_dir

  -- FIXME: ps aux help, elan stdlib
  return vim.lsp.start(start_config)
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
