---@mod lean.diagnostic Diagnostics

local std = require 'std.lsp'

---@brief [[
--- Low-level Lean-specific diagnostic support (as in `vim.diagnostic` and its
--- LSP-specific behaviors).
---@brief ]]

---Represents a diagnostic, such as a compiler error or warning.
---Diagnostic objects are only valid in the scope of a resource.
---
---LSP accepts a `Diagnostic := DiagnosticWith String`.
---The infoview also accepts `InteractiveDiagnostic := DiagnosticWith (TaggedText MsgEmbed)`.
---[reference](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#diagnostic)
---@class DiagnosticWith<M>: { message : M }
---@field range lsp.Range The range at which the message applies.
---@field fullRange? lsp.Range Extension: preserve semantic range of errors when truncating them for display purposes.
---@field severity? lsp.DiagnosticSeverity
---@field isSilent? boolean Extension: whether this diagnostic should not be displayed as a regular diagnostic.
---@field code? string|integer The diagnostic's code, which might appear in the user interface.
---@field source? string A human-readable string describing the source of this diagnostic.
---@field tags? lsp.DiagnosticTag[] Additional metadata about the diagnostic.
---@field leanTags? LeanDiagnosticTag[] Additional Lean-specific metadata about the diagnostic.
---@field relatedInformation? DiagnosticRelatedInformation[] An array of related diagnostic information,
---                                                          e.g. when symbol-names within a scope collide all
---                                                          definitions can be marked via this property.
---@field data? any A data entry field that is preserved between a
---                 `textDocument/publishDiagnostics` notification and
---                 `textDocument/codeAction` request.

---Represents a related message and source code location for a diagnostic.
---This should be used to point to code locations that cause or are related to
---a diagnostics, e.g when duplicating a symbol in a scope.
---@class DiagnosticRelatedInformation
---@field location lsp.Location
---@field message string

---@class LeanFileProgressParams
---@field textDocument lsp.VersionedTextDocumentIdentifier
---@field processing LeanFileProgressProcessingInfo[]

---@class LeanPublishDiagnosticsParams: lsp.PublishDiagnosticsParams
---@field diagnostics DiagnosticWith<string>[]

local M = {
  ---Custom diagnostic tags provided by the language server.
  ---We use a separate diagnostic field for this to avoid confusing LSP clients with our custom tags.
  ---@enum LeanDiagnosticTag
  LeanDiagnosticTag = {
    ---Diagnostics representing an "unsolved goals" error.
    ---Corresponds to `MessageData.tagged `Tactic.unsolvedGoals ..`.
    unsolvedGoals = 1,
    ---Diagnostics representing a "goals accomplished" silent message.
    ---Corresponds to `MessageData.tagged `goalsAccomplished ..`.
    goalsAccomplished = 2,
  },

  ---The range of a Lean diagnostic.
  ---
  ---Prioritizes `fullRange`, which is the "real" range of the diagnostic, not
  ---the `range`, which clips to just its first line.
  ---@param diagnostic DiagnosticWith<any>
  ---@return lsp.Range range
  range_of = function(diagnostic)
    return diagnostic.fullRange or diagnostic.range
  end,
}

---Is this a goals accomplished diagnostic?
---@generic T
---@param diagnostic DiagnosticWith<T>
---@return boolean
function M.is_unsolved_goals(diagnostic)
  return vim.deep_equal(diagnostic.leanTags, { M.LeanDiagnosticTag.unsolvedGoals })
end

---Is this a goals accomplished diagnostic?
---@generic T
---@param diagnostic DiagnosticWith<T>
---@return boolean
function M.is_goals_accomplished(diagnostic)
  return vim.deep_equal(diagnostic.leanTags, { M.LeanDiagnosticTag.goalsAccomplished })
end

---Convert Lean ranges to byte indices.
---
---Prioritizes `fullRange`, which is the "real" range of the diagnostic, not
---the `range`, which clips to just its first line.
---
---Returned positions are 0-indexed.
---@param bufnr integer
---@param diagnostic DiagnosticWith<string>
---@return integer start_row
---@return integer start_col
---@return integer end_row
---@return integer end_col
function M.byterange_of(bufnr, diagnostic)
  local range = M.range_of(diagnostic)
  local start = std.position_to_byte0(range.start, bufnr)
  local _end = std.position_to_byte0(range['end'], bufnr)
  return start[1], start[2], _end[1], _end[2]
end

---@param diagnostics DiagnosticWith<string>[]
---@param bufnr integer
---@param client_id integer
---@return vim.Diagnostic[]
function M.leanls_to_vim(diagnostics, bufnr, client_id)
  ---@param diagnostic DiagnosticWith<string>
  ---@return vim.Diagnostic
  return vim.tbl_map(function(diagnostic)
    local start_row, start_col, end_row, end_col = M.byterange_of(bufnr, diagnostic)
    ---@type vim.Diagnostic
    return {
      lnum = start_row,
      col = start_col,
      end_lnum = end_row,
      end_col = end_col,
      severity = std.severity_lsp_to_vim(diagnostic.severity),
      message = diagnostic.message,
      source = diagnostic.source,
      code = diagnostic.code,
      _tags = std.tags_lsp_to_vim(diagnostic, client_id),
      user_data = { lsp = diagnostic },
    }
  end, diagnostics)
end

return M
