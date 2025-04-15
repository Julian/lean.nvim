local lsp = {}

---Convert an LSP position to a (0, 0)-indexed tuple.
---
---These are used by extmarks.
---See `:h api-indexing` for details.
---@param position lsp.Position
---@param line string the line contents for this position's line
---@return { [1]: integer, [2]: integer } position
function lsp.position_to_byte0(position, line)
  local ok, col = pcall(vim.str_byteindex, line, position.character, true)
  return { position.line, ok and col or position.character }
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

-- vim.lsp.diagnostic has a *private* `diagnostic_lsp_to_vim` :/ ...
--
-- the below comes from there / is required for assembling vim.Diagnostic
-- objects out of LSP responses

---@param bufnr integer
---@return string[]?
function lsp.get_buf_lines(bufnr)
  if vim.api.nvim_buf_is_loaded(bufnr) then
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  local f = io.open(filename)
  if not f then
    return
  end

  local content = f:read '*a'
  if not content then
    -- Some LSP servers report diagnostics at a directory level, in which case
    -- io.read() returns nil
    f:close()
    return
  end

  local lines = vim.split(content, '\n')
  f:close()
  return lines
end

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
