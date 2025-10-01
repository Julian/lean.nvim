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
  local hls = vim.api.nvim_buf_get_extmarks(buffer.bufnr, lsp.goals_ns, pos, pos, {
    details = true,
    overlap = true,
    type = 'highlight',
  })
  return vim.iter(hls):any(function(hl)
    return hl[4].hl_group == 'leanGoalsAccomplished'
  end)
end

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
  client:notify(ms.textDocument_didOpen, {
    textDocument = {
      version = 0,
      uri = uri,
      languageId = 'lean',
      text = std.buf_get_full_text(bufnr),
    },
  })
end

return lsp
