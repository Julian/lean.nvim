---@mod lean.lsp LSP

---@brief [[
--- Low-level interaction with the Lean language server.
---@brief ]]

local ms = vim.lsp.protocol.Methods

local Buffer = require 'std.nvim.buffer'
local std = require 'std.lsp'

local log = require 'lean.log'

local lsp = {
  ---A namespace where we put Lean's "silent" diagnostics.
  silent_ns = vim.api.nvim_create_namespace 'lean.diagnostic.silent',
  ---A namespace for Lean's unsolved goal markers.and goals accomplished ranges
  goals_ns = vim.api.nvim_create_namespace 'lean.goal.markers',
}

---@class LeanClientCapabilities : lsp.ClientCapabilities
---@field silentDiagnosticSupport? boolean Whether the client supports `DiagnosticWith.isSilent = true`.

---@class LeanClientConfig : vim.lsp.ClientConfig
---@field lean? LeanClientCapabilities

---Find the `vim.lsp.Client` attached to the given buffer.
---@param bufnr? number
---@return vim.lsp.Client?
function lsp.client_for(bufnr)
  local clients = vim.lsp.get_clients { name = 'leanls', bufnr = bufnr or 0 }
  return clients[1]
end

---Is the given line within a range of a goals accomplished marker?
---@param params lsp.TextDocumentPositionParams the document position in question
---@return boolean? accomplished whether there's a marker at the cursor, or nil if the buffer isn't loaded
function lsp.goals_accomplished_at(params)
  local buffer = Buffer:from_uri(params.textDocument.uri)
  if not buffer:is_loaded() then
    return
  end

  local pos = { params.position.line, 0 }

  local opts = { details = true, overlap = true, type = 'highlight' }
  local hls = buffer:extmarks(lsp.goals_ns, pos, pos, opts)
  return vim.iter(hls):any(function(hl)
    return hl[4].hl_group == 'leanGoalsAccomplished'
  end)
end

---@class LeanDidOpenTextDocumentParams: lsp.DidOpenTextDocumentParams
---@field textDocument LeanTextDocumentItem
---@field dependencyBuildMode 'always'|'never'|'once'

---@class LeanTextDocumentItem: lsp.TextDocumentItem
---@field languageId 'lean'

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

  client:notify(ms.textDocument_didClose, { textDocument = { uri = uri } })
  local params = { ---@type LeanDidOpenTextDocumentParams
    textDocument = {
      version = 0,
      uri = uri,
      languageId = 'lean',
      text = std.buf_get_full_text(bufnr),
    },
  }
  client:notify(ms.textDocument_didOpen, params)
end

---@class WaitForDiagnosticsParams
---@field uri lsp.DocumentUri
---@field version number

---@class WaitForILeansParams
---@field uri? lsp.DocumentUri
---@field version? number

---@param bufnr? number
local function uri_and_version_params(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return {
    uri = vim.uri_from_bufnr(bufnr),
    version = vim.lsp.util.buf_versions[bufnr],
  }
end

---@type fun(number?): WaitForDiagnosticsParams
lsp.make_wait_for_diagnostics_params = uri_and_version_params

---@type fun(number?): WaitForILeansParams
lsp.make_wait_for_ileans_params = uri_and_version_params

return lsp
