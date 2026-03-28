---@mod lean.diagnostic Diagnostics

local log = require 'lean.log'
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

local diagnostic = {
  ---A namespace for our diagnostic signs (replacing vim.diagnostic's built-in signs).
  signs_ns = vim.api.nvim_create_namespace 'lean.diagnostic.signs',

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

vim.cmd.highlight [[default link leanUnsolvedGoals DiagnosticInfo]]
vim.cmd.highlight [[default link leanGoalsAccomplishedSign DiagnosticInfo]]

---Get the sign character for a given severity.
---
---Respects the user's `vim.diagnostic.config().signs.text` if set,
---so that lean.nvim's custom sign rendering honours the same configuration
---as Neovim's built-in handler would.
---Falls back to Neovim's own default: the first letter of the severity name,
---uppercased (E/W/I/H).
---@param severity vim.diagnostic.Severity
---@param signs_text? table<vim.diagnostic.Severity, string> pre-fetched from vim.diagnostic.config().signs.text
---@return string
local function severity_sign(severity, signs_text)
  if signs_text then
    local text = signs_text[severity]
    if text then
      return text
    end
  end
  local name = vim.diagnostic.severity[severity]
  return name and name:sub(1, 1) or 'E'
end

---Characters used for multi-line full-range indicators.
local full_range_chars = {
  top = '┌',
  mid = '│',
  bot = '└',
}

---@type table<vim.diagnostic.Severity, string>
local severity_sign_hl = {
  [vim.diagnostic.severity.ERROR] = 'DiagnosticSignError',
  [vim.diagnostic.severity.WARN] = 'DiagnosticSignWarn',
  [vim.diagnostic.severity.INFO] = 'DiagnosticSignInfo',
  [vim.diagnostic.severity.HINT] = 'DiagnosticSignHint',
}

---Extmark priority per severity (higher severity = higher priority).
local severity_priority = {
  [vim.diagnostic.severity.ERROR] = 14,
  [vim.diagnostic.severity.WARN] = 13,
  [vim.diagnostic.severity.INFO] = 12,
  [vim.diagnostic.severity.HINT] = 11,
}

---Is this an unsolved goals diagnostic?
---@generic T
---@param diag DiagnosticWith<T>
---@return boolean
function diagnostic.is_unsolved_goals(diag)
  return vim.deep_equal(diag.leanTags, { diagnostic.LeanDiagnosticTag.unsolvedGoals })
end

---Is this a goals accomplished diagnostic?
---@generic T
---@param diag DiagnosticWith<T>
---@return boolean
function diagnostic.is_goals_accomplished(diag)
  return vim.deep_equal(diag.leanTags, { diagnostic.LeanDiagnosticTag.goalsAccomplished })
end

---Convert Lean ranges to byte indices.
---
---Prioritizes `fullRange`, which is the "real" range of the diagnostic, not
---the `range`, which clips to just its first line.
---
---Returned positions are 0-indexed.
---@param bufnr integer
---@param diag DiagnosticWith<string>
---@return integer start_row
---@return integer start_col
---@return integer end_row
---@return integer end_col
function diagnostic.byterange_of(bufnr, diag)
  local range = diagnostic.range_of(diag)
  local start = std.position_to_byte0(range.start, bufnr)
  local _end = std.position_to_byte0(range['end'], bufnr)
  return start[1], start[2], _end[1], _end[2]
end

---@param diagnostics DiagnosticWith<string>[]
---@param bufnr integer
---@param client_id integer
---@return vim.Diagnostic[]
function diagnostic.leanls_to_vim(diagnostics, bufnr, client_id)
  ---@param diag DiagnosticWith<string>
  ---@return vim.Diagnostic
  return vim.tbl_map(function(diag)
    local start_row, start_col, end_row, end_col = diagnostic.byterange_of(bufnr, diag)
    ---@type vim.Diagnostic
    return {
      lnum = start_row,
      col = start_col,
      end_lnum = end_row,
      end_col = end_col,
      severity = std.severity_lsp_to_vim(diag.severity),
      message = diag.message,
      source = diag.source,
      code = diag.code,
      _tags = std.tags_lsp_to_vim(diag, client_id),
      user_data = { lsp = diag },
    }
  end, diagnostics)
end

---@type table<integer, true>
local disabled_builtin_signs = {}

---Disable vim.diagnostic's built-in signs for a given LSP client.
---
---This calls `vim.diagnostic.config({ signs = false }, ns)` on the client's
---diagnostic namespace. Called once per client; idempotent thereafter.
---@param client_id integer
function diagnostic.disable_builtin_signs(client_id)
  if disabled_builtin_signs[client_id] then
    return
  end
  local ns = vim.lsp.diagnostic.get_namespace(client_id)
  vim.diagnostic.config({ signs = false }, ns)
  disabled_builtin_signs[client_id] = true
end

---Render diagnostic signs for all diagnostics.
---
---Replaces vim.diagnostic's built-in sign column display. For diagnostics
---whose `fullRange` extends past the clipped `range`, draws `┌│└` guide
---characters. For single-line diagnostics, draws the standard severity sign.
---All signs are colored by severity, and higher severities take priority.
---
---@param buffer Buffer the buffer to render in
---@param diagnostics DiagnosticWith<string>[] the raw LSP diagnostics
function diagnostic.render_signs(buffer, diagnostics)
  local signs_config = vim.diagnostic.config() or {}
  local signs_text = type(signs_config.signs) == 'table' and signs_config.signs.text or nil

  for _, diag in ipairs(diagnostics) do
    local severity = std.severity_lsp_to_vim(diag.severity)
    local hl = severity_sign_hl[severity] or severity_sign_hl[vim.diagnostic.severity.ERROR]
    local priority = severity_priority[severity] or severity_priority[vim.diagnostic.severity.ERROR]

    -- Does this diagnostic have a multi-line fullRange that differs from range?
    local has_full_range = diag.fullRange
      and diag.fullRange['end'].line > diag.range['end'].line
      and not (
        diag.fullRange.start.line == 0
        and diag.fullRange['end'].line >= buffer:line_count() - 1
      )

    local ok = pcall(function()
      if has_full_range then
        local start_pos = std.position_to_byte0(diag.fullRange.start, buffer.bufnr)
        local end_pos = std.position_to_byte0(diag.fullRange['end'], buffer.bufnr)

        local start_line = start_pos[1]
        local end_line = end_pos[1]

        if end_line <= start_line then
          return
        end

        -- If the end is at column 0, the range actually ends at the
        -- end of the previous line.
        if end_pos[2] == 0 then
          end_line = end_line - 1
        end

        if end_line <= start_line then
          return
        end

        buffer:set_extmark(diagnostic.signs_ns, start_line, 0, {
          sign_text = full_range_chars.top,
          sign_hl_group = hl,
          priority = priority,
        })

        for line = start_line + 1, end_line - 1 do
          buffer:set_extmark(diagnostic.signs_ns, line, 0, {
            sign_text = full_range_chars.mid,
            sign_hl_group = hl,
            priority = priority,
          })
        end

        buffer:set_extmark(diagnostic.signs_ns, end_line, 0, {
          sign_text = full_range_chars.bot,
          sign_hl_group = hl,
          priority = priority,
        })
      else
        local start_pos = std.position_to_byte0(diag.range.start, buffer.bufnr)

        buffer:set_extmark(diagnostic.signs_ns, start_pos[1], 0, {
          sign_text = severity_sign(severity, signs_text),
          sign_hl_group = hl,
          priority = priority,
        })
      end
    end)

    if not ok then
      log:debug {
        message = 'Failed to set diagnostic sign',
        diagnostic = diag,
        bufnr = buffer.bufnr,
      }
    end
  end
end

---Clear all diagnostic signs from a buffer.
---@param buffer Buffer
function diagnostic.clear_signs(buffer)
  buffer:clear_namespace(diagnostic.signs_ns)
end

return diagnostic
