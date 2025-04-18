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

---Polyfill vim.fs.relpath-ish for Neovim < 0.11.
---
---Don't use this for real filesystem operations (as opposed to display),
---its implementation is naive!
local relpath = vim.fs.relpath
  or function(base, target)
    if vim.startswith(target, base .. '/') then
      return target:sub(#base + 2)
    end
    return target
  end

---Convert LSP document params inside the current buffer to a human-readable (1, 1)-indexed string.
---
---Takes the workspace into account in order to return a relative path.
---@param params UIParams
function lsp.text_document_position_to_string(params)
  local workspace = vim.lsp.buf.list_workspace_folders()[1] or vim.uv.cwd()
  local filename = vim.uri_to_fname(params.textDocument.uri)

  return ('%s at %d:%d'):format(
    relpath(workspace, filename) or filename,
    params.position.line + 1,
    params.position.character + 1
  )
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
