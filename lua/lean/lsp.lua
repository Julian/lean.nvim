---@mod lean.lsp LSP

---@brief [[
--- Low-level interaction with the Lean language server.
---@brief ]]

local ms = vim.lsp.protocol.Methods

local log = require 'lean.log'
local util = require 'lean._util'

local lsp = { handlers = {} }

function lsp.enable(opts)
  opts.handlers = vim.tbl_extend('keep', opts.handlers or {}, {
    ['$/lean/fileProgress'] = lsp.handlers.file_progress_handler,
  })
  opts.init_options = vim.tbl_extend('keep', opts.init_options or {}, {
    editDelay = 10, -- see #289
    hasWidgets = true,
  })
  require('lspconfig').leanls.setup(opts)
end

---Find the `vim.lsp.Client` attached to the given buffer.
---@param bufnr? number
---@return vim.lsp.Client
function lsp.client_for(bufnr)
  local clients = vim.lsp.get_clients { name = 'leanls', bufnr = bufnr or 0 }
  return clients[1]
end

---@class PlainGoal
---@field rendered string The goals as pretty-printed Markdown, or something like "no goals" if accomplished.
---@field goals string[] The pretty-printed goals, empty if all accomplished.

---Fetch goal state information from the server (async).
---@param params lsp.TextDocumentPositionParams
---@param bufnr number
---@return LspError|nil error
---@return PlainGoal|nil plain_goal
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

---@class PlainTermGoal
---@field goal string
---@field range lsp.Range

---Fetch term goal state information from the server (async).
---@param params lsp.TextDocumentPositionParams
---@param bufnr number
---@return LspError|nil error
---@return PlainTermGoal|nil plain_term_goal
function lsp.plain_term_goal(params, bufnr)
  local client = lsp.client_for(bufnr)
  if not client then
    return 'LSP server not connected', nil
  end
  return util.client_a_request(client, '$/lean/plainTermGoal', params)
end

---@class LeanFileProgressParams
---@field textDocument lsp.VersionedTextDocumentIdentifier
---@field processing LeanFileProgressProcessingInfo[]

---Called when `$/lean/fileProgress` is triggered.
---@param err LspError?
---@param params LeanFileProgressParams
function lsp.handlers.file_progress_handler(err, params)
  log:trace {
    message = 'got fileProgress',
    err = err,
    params = params,
  }

  if err ~= nil then
    return
  end

  require('lean.progress').update(params)
  -- XXX: Similar to the equivalent line below, this second pcall seems to have
  --      become necessary when we started deleting clean buffers in tests.
  --      That's.. very suspicious, because it probably means it's necessary
  --      for "real life" use cases as well. So something isn't being handled
  --      correctly here. Without this though, tests in the sorry spec?? and
  --      not others seem to fail nondeterministically around 50% of the time.
  pcall(require('lean.infoview').__update_pin_by_uri, params.textDocument.uri)

  require('lean.progress_bars').update(params)
end

vim.api.nvim_create_autocmd('DiagnosticChanged', {
  group = vim.api.nvim_create_augroup('LeanDiagnostics', {}),
  callback = function(args)
    local diagnostics = args.data.diagnostics

    log:trace {
      message = 'got diagnostics',
      bufnr = args.buf,
      diagnostics = diagnostics,
    }

    vim.schedule(function()
      require('lean.infoview').__update_pin_by_uri(vim.uri_from_bufnr(args.buf))
    end)
  end,
})

---Restart the Lean server for an open Lean 4 file.
---See e.g. https://github.com/leanprover/lean4/blob/master/src/Lean/Server/README.md#recompilation-of-opened-files
---@param bufnr? number
function lsp.restart_file(bufnr)
  bufnr = bufnr or 0
  local client = lsp.client_for(bufnr)
  if not client then
    log:info {
      message = "Cannot refresh file dependencies, this isn't a Lean file.",
      bufnr = bufnr,
    }
    return
  end
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
