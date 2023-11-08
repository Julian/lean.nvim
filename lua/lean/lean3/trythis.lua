local lean_lsp_diagnostics = require('lean._util').lean_lsp_diagnostics

local trythis = {}

local DOUBLE_AT = vim.regex[[ at .*\ze at .*]]
local BY_EXACT = vim.regex[[\<\(by exact \)\|\(begin\_s*exact.*\_s*end\)]]

local function suggestions_from(diagnostic)
  local suggestions = {}
  local trimmed = diagnostic.message:gsub('^.-Try this:%s*', '')
  for suggestion in vim.gsplit(trimmed, 'Try this:') do
    table.insert(
      suggestions,
      { replacement = vim.trim(suggestion, '\r\n'),
        lnum = diagnostic.lnum,
        col = diagnostic.col }
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
  local diagnostics = lean_lsp_diagnostics{
    lnum = vim.api.nvim_win_get_cursor(0)[1] - 1,
    severity = vim.diagnostic.severity.INFO,
  }
  for _, diagnostic in ipairs(diagnostics) do
    local suggestions = suggestions_from(diagnostic)
    if not vim.tbl_isempty(suggestions) then
      local suggestion = suggestions[1]

      local start_row = suggestion.lnum
      local start_col = suggestion.col

      vim.api.nvim_win_set_cursor(0, {start_row + 1, start_col})
      local end_row, end_col = unpack(vim.fn.searchpos('\\>', 'cW'))

      local rest = vim.api.nvim_buf_get_text(0, end_row - 1, end_col - 1, end_row - 1, -1, {})[1]
      if rest:match('%s*[[{]') then
        local bracket_row, bracket_col = unpack(vim.fn.searchpairpos('\\s\\*[[{]', '', '[\\]}]', 'cW'))
        if bracket_row ~= 0 or bracket_col ~= 0 then
          end_row, end_col = bracket_row, bracket_col + 1
        end
      end

      vim.api.nvim_buf_set_text(
        0,
        start_row,
        start_col,
        end_row - 1,
        end_col - 1,
        vim.split(suggestion.replacement, '\n')
      )

      trythis.trim_doubled_ats()
      trythis.trim_unnecessary_mode_switching()
      return
    end
  end
end

--- Trim unnecessary switching between tactic and term modes.
--
--  Right now only handles `by exact`.
function trythis.trim_unnecessary_mode_switching()
  local start_col, end_col = BY_EXACT:match_str(vim.api.nvim_get_current_line())
  if start_col ~= nil then
    local start_row, _ = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_text(0, start_row - 1, start_col, start_row - 1, end_col, {})
  end
end

--- Trim `at foo at foo` to just `at foo` once.
function trythis.trim_doubled_ats()
  local start_col, end_col = DOUBLE_AT:match_str(vim.api.nvim_get_current_line())
  if not start_col then return end
  local start_row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  vim.api.nvim_buf_set_text(
    0,
    start_row - 1,
    start_col,
    start_row - 1,
    end_col,
    {}
  )
end

return trythis
