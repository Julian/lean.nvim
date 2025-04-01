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

---Convert an LSP position to a (1, 1)-indexed string.
---
---We use 1-based indexing here as this is meant for human-readable strings,
---and the `gg` and `|` motions are 1-indexed, which is the most likely way a
---human (you!) will interact with this information.
---@param range lsp.Range
function lsp.range_to_string(range)
  return ('%d:%d-%d:%d'):format(
    range.start.line + 1,
    range.start.character + 1,
    range['end'].line + 1,
    range['end'].character + 1
  )
end

return lsp
