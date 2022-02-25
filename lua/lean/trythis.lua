local DiagnosticSeverity = require('vim.lsp.protocol').DiagnosticSeverity

local trythis = {}


local function suggestions_from(diagnostic)
  local suggestions = {}
  local trimmed = diagnostic.message:gsub('^.-Try this:%s*', '')
  for suggestion in vim.gsplit(trimmed, 'Try this:') do
    table.insert(
      suggestions,
      { replacement = vim.trim(suggestion, '\r\n'),
        -- neovim 0.5
        range = diagnostic.range,
        -- neovim 0.6
        lnum = diagnostic.lnum, col = diagnostic.col }
    )
  end
  return suggestions
end

--- Swap the first suggestion from Lean with the word under the cursor.
--
--  Doesn't do any robust error checking, or allow rotating for later results
--  yet.
--
--  luacheck: ignore
--  See https://github.com/leanprover/vscode-lean/blob/8ad0609f560f279512ff792589f06d18aa92fb3f/src/tacticsuggestions.ts#L76
--  for the VSCode implementation.
function trythis.swap()
  local diagnostics = vim.diagnostic ~= nil
    and -- neovim 0.6
      vim.diagnostic.get(0, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1, severity = DiagnosticSeverity.Information })
    or -- neovim 0.5
      vim.lsp.diagnostic.get_line_diagnostics(0, nil, { severity = DiagnosticSeverity.Information })
  for _, diagnostic in ipairs(diagnostics) do
    local suggestions = suggestions_from(diagnostic)
    if not vim.tbl_isempty(suggestions) then
      local suggestion = suggestions[1]

      local start_row = suggestion.lnum
        or suggestion.range.start.line -- neovim 0.5
      local start_col = suggestion.col
        or vim.fn.byteidx(vim.api.nvim_get_current_line(), suggestion.range.start.character) -- neovim 0.5

      vim.api.nvim_win_set_cursor(0, {start_row + 1, start_col})
      local end_row, end_col = unpack(vim.fn.searchpos('\\>', 'c'))

      vim.api.nvim_buf_set_text(
        0,
        start_row,
        start_col,
        end_row - 1,
        end_col - 1,
        vim.split(suggestion.replacement, '\n')
      )

      trythis.trim_doubled_ats(suggestion.replacement:match(' at .*'))
      trythis.trim_unnecessary_mode_switching()
      return
    end
  end
end

--- Trim unnecessary switching between tactic and term modes.
--
--  Right now only handles `by exact`.
function trythis.trim_unnecessary_mode_switching()
  local line = vim.api.nvim_get_current_line()
  local start_col, end_col = line:find(' by exact ')
  if start_col ~= nil then
    local start_row, _ = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_text(0, start_row - 1, start_col, start_row - 1, end_col, {})
  end
end

--- Trim `at foo at foo` to just `at foo` once.
function trythis.trim_doubled_ats(at)
  if not at then return end
  local line = vim.api.nvim_get_current_line()
  local start_col, end_col = line:find(at .. at)
  if start_col ~= nil then
    local start_row, _ = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_text(
      0,
      start_row - 1,
      start_col,
      start_row - 1,
      end_col - #at + 1,
      {}
    )
  end
end

return trythis
