local M = {}

local _CURSOR_MARKER = '$CURSOR'

--- Load the Lean abbreviations as a Lua table.
function M.load()
  local this_file = debug.getinfo(2, "S").source:sub(2)
  local base_directory = vim.fn.fnamemodify(this_file, ":h:h:h")
  local path = base_directory .. '/vscode-lean/abbreviations.json'
  return vim.fn.json_decode(vim.fn.readfile(path))
end

local function add_leader(leader, abbrevs)
  local with_leader = {}
  for from, to in pairs(abbrevs) do
    with_leader[leader .. from] = to
  end
  return with_leader
end

local function compe_nvim_enable(compe, lean_abbreviations)
  local Source = require'lean._compe'.new(lean_abbreviations)
  compe.register_source('lean_abbreviations', Source)

  local Config = require('compe.config').get()
  Config.source = Config.source or {}
  Config.source['lean_abbreviations'] = { disabled = false }
end

local function snippets_nvim_enable(snippets, lean_abbreviations)
  for from, to in pairs(lean_abbreviations) do
    lean_abbreviations[from] = to:gsub(_CURSOR_MARKER, '$0')
  end

  local all_snippets = snippets.snippets or {}
  all_snippets.lean3 = lean_abbreviations
  all_snippets.lean = lean_abbreviations
  snippets.snippets = all_snippets
end

local abbr_mark_ns = vim.api.nvim_create_namespace('leanAbbreviationMark')

local function get_extmark_range(abbr_ns, id, buffer)
  local row, col, details = unpack(
    vim.api.nvim_buf_get_extmark_by_id(buffer or 0, abbr_ns, id, {details = true}))
  return row, col, details and details.end_row, details and details.end_col
end

local function _clear_abbr_mark()
  vim.api.nvim_buf_del_extmark(0, abbr_mark_ns, M.abbr_mark)
  M.abbr_mark = nil
  vim.api.nvim_buf_del_keymap(0, 'i', '<CR>')
  vim.api.nvim_buf_del_keymap(0, 'i', '<Tab>')
end

function M._insert_char_pre()
  local char = vim.api.nvim_get_vvar('char')

  if M.abbr_mark then
    if vim.tbl_contains({'{', '}', '(', ')', ' '}, char) then
      return M.convert(true)
    end
  end

  -- typing \\ should result in \ and exit abbreviation mode
  if M.abbr_mark and char == M.leader then
    local row1, col1, row2, col2 = get_extmark_range(abbr_mark_ns, M.abbr_mark)
    if row1 and row1 == row2 then
      local text = vim.api.nvim_buf_get_lines(0, row1, row1+1, true)[1]:sub(col1 + 1, col2)
      if text == M.leader then
        _clear_abbr_mark()
        local tmp_extmark = vim.api.nvim_buf_set_extmark(0, abbr_mark_ns, row1, col1,
          { end_line = row2, end_col = col2 })
        return vim.schedule(function()
          row1, col1, row2, col2 = get_extmark_range(abbr_mark_ns, tmp_extmark)
          if not row1 then return end
          vim.api.nvim_buf_del_extmark(0, abbr_mark_ns, tmp_extmark)
          vim.api.nvim_buf_set_text(0, row1, col1, row2, col2, {})
        end)
      end
    end
  end

  if not M.abbr_mark and char == M.leader then
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    row = row - 1
    M.abbr_mark = vim.api.nvim_buf_set_extmark(0, abbr_mark_ns, row, col, {
      hl_group = 'leanAbbreviationMark',
      end_line = row,
      end_col = col,
      right_gravity = false,
      end_right_gravity = true,
    })
    -- override only for the duration of the abbreviation (clashes with autocompletion plugins)
    vim.api.nvim_buf_set_keymap(0, 'i', '<CR>', 'v:lua._lean_abbreviations_enter_expr()', {expr = true, noremap = true})
    vim.api.nvim_buf_set_keymap(0, 'i', '<Tab>', 'v:lua._lean_abbreviations_tab_expr()', {expr = true, noremap = true})
    return
  end
end

function _G._lean_abbreviations_enter_expr()
  M.convert(true)
  return '\n'
end

function _G._lean_abbreviations_tab_expr()
  M.convert(true)
  return ' '
end

local function convert_abbrev(abbrev)
  if abbrev:find(M.leader) ~= 1 then return abbrev end
  abbrev = abbrev:sub(#M.leader + 1)
  if abbrev:find(M.leader) == 1 then
    return M.leader .. convert_abbrev(abbrev:sub(#M.leader + 1))
  end
  local matchlen, fromlen, repl = 0, 99999, ""
  for from, to in pairs(M.abbreviations) do
    local curmatchlen = 0
    for i = 1, math.min(#abbrev, #from) do
      if abbrev:byte(i) == from:byte(i) then
        curmatchlen = i
      else
        break
      end
    end
    if curmatchlen > matchlen or (curmatchlen == matchlen and #from < fromlen) then
      matchlen, fromlen, repl = curmatchlen, #from, to
    end
  end
  if matchlen == 0 then return M.leader .. abbrev end
  return repl .. convert_abbrev(abbrev:sub(matchlen + 1))
end

function M.convert(needs_schedule)
  if not M.abbr_mark then return end
  local row1, col1, row2, col2 = get_extmark_range(abbr_mark_ns, M.abbr_mark)
  _clear_abbr_mark()
  if not row1 then return end

  local tmp_extmark = vim.api.nvim_buf_set_extmark(0, abbr_mark_ns, row1, col1,
    { end_line = row2, end_col = col2 })
  local conv = function()
    row1, col1, row2, col2 = get_extmark_range(abbr_mark_ns, tmp_extmark)
    if not row1 or row1 ~= row2 then return end
    vim.api.nvim_buf_del_extmark(0, abbr_mark_ns, tmp_extmark)
    local text = vim.api.nvim_buf_get_lines(0, row1, row1+1, true)[1]:sub(col1 + 1, col2)
    vim.api.nvim_buf_set_text(0, row1, col1, row2, col2, {convert_abbrev(text)})
  end
  if needs_schedule then vim.schedule(conv) else conv() end
end

local function enable_builtin()
  vim.api.nvim_exec([[
    augroup LeanAbbreviations
      autocmd!
      autocmd InsertCharPre *.lean lua require'lean.abbreviations'._insert_char_pre()
      autocmd InsertLeave *.lean lua require'lean.abbreviations'.convert()
      autocmd BufLeave *.lean lua require'lean.abbreviations'.convert()
    augroup END
    hi def leanAbbreviationMark cterm=underline gui=underline guisp=Gray
  ]], false)
  -- CursorMoved CursorMovedI as well?
end

function M.enable(opts)
  M.leader = opts.leader or '\\'

  M.abbreviations = M.load()
  for from, to in pairs(opts.extra or {}) do
    M.abbreviations[from] = to
  end

  if opts.snippets then
    snippets_nvim_enable(require('snippets'), add_leader(M.leader, M.abbreviations))
  end

  if opts.compe then
    compe_nvim_enable(require('compe'), add_leader(M.leader, M.abbreviations))
  end

  if opts.builtin then
    enable_builtin()
  end
end

return M
