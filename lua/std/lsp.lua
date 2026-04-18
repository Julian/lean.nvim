local lsp = {}

---Convert an LSP position to a (0, 0)-indexed tuple.
---
---These are used by extmarks.
---See `:h api-indexing` for details.
---@param position lsp.Position
---@param bufnr integer the buffer whose position is referred to
---@return { [1]: integer, [2]: integer } position
function lsp.position_to_byte0(position, bufnr)
  local line = vim.api.nvim_buf_get_lines(bufnr, position.line, position.line + 1, false)[1] or ''
  local ok, col = pcall(vim.str_byteindex, line, 'utf-16', position.character)
  return { position.line, ok and col or position.character }
end

---Convert a 0-indexed byte column to a 0-indexed UTF-16 column.
---
---LSP uses UTF-16 for character offsets; this is the inverse of the
---byte-column conversion done in `position_to_byte0`.
---Returns 0 if the line is nil or the conversion fails.
---@param buf_line? string the line text
---@param byte_col integer 0-indexed byte offset
---@return integer utf16_col 0-indexed UTF-16 offset
function lsp.byte_col_to_utf16(buf_line, byte_col)
  if not buf_line then
    return 0
  end
  local ok, utf16 = pcall(vim.str_utfindex, buf_line, 'utf-16', byte_col)
  if ok then
    return utf16
  end
  require('lean.log'):debug {
    message = 'str_utfindex failed',
    buf_line = buf_line,
    byte_col = byte_col,
  }
  return 0
end

---Convert an LSP range to a human-readable (1, 1)-indexed string.
---
---We use 1-based indexing here as the `gg` and `|` motions are 1-indexed,
---which is the most likely way a human (you?) will interact with this
---information.
---@param range lsp.Range
function lsp.range_to_string(range)
  return ('%d:%d-%d:%d'):format(
    range.start.line + 1,
    range.start.character + 1,
    range['end'].line + 1,
    range['end'].character + 1
  )
end

-- ~*~ vim.lsp._private_functions we still need... ~*~

local format_line_ending = {
  ['unix'] = '\n',
  ['dos'] = '\r\n',
  ['mac'] = '\r',
}

---@private
---@param bufnr (number)
---@return string
local function buf_get_line_ending(bufnr)
  return format_line_ending[vim.bo[bufnr].fileformat] or '\n'
end

---@private
---Returns full text of buffer {bufnr} as a string.
---
---@param bufnr (number) Buffer handle, or 0 for current.
---@return string # Buffer text as string.
function lsp.buf_get_full_text(bufnr)
  local line_ending = buf_get_line_ending(bufnr)
  local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, true), line_ending)
  if vim.bo[bufnr].eol then
    text = text .. line_ending
  end
  return text
end

-- vim.lsp.diagnostic has a *private* `diagnostic_lsp_to_vim` :/ ...
--
-- the below comes from there / is required for assembling vim.Diagnostic
-- objects out of LSP responses

---@param severity lsp.DiagnosticSeverity
function lsp.severity_lsp_to_vim(severity)
  if type(severity) == 'string' then
    severity = vim.lsp.protocol.DiagnosticSeverity[severity] ---@type integer
  end
  return severity
end

---@param diagnostic lsp.Diagnostic
---@param client_id integer
---@return table?
function lsp.tags_lsp_to_vim(diagnostic, client_id)
  local tags ---@type table?
  for _, tag in ipairs(diagnostic.tags or {}) do
    if tag == vim.lsp.protocol.DiagnosticTag.Unnecessary then
      tags = tags or {}
      tags.unnecessary = true
    elseif tag == vim.lsp.protocol.DiagnosticTag.Deprecated then
      tags = tags or {}
      tags.deprecated = true
    else
      vim.lsp.log.info(string.format('Unknown DiagnosticTag %d from LSP client %d', tag, client_id))
    end
  end
  return tags
end

return lsp
