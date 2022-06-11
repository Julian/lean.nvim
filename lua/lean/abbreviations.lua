---@brief [[
--- Support for abbreviations (unicode character replacement).
---@brief ]]

---@tag lean.abbreviations

local set_augroup = require('lean._util').set_augroup

local abbreviations = {}

local buf_imaps = {}
local _MEMOIZED = nil

--- Load the Lean abbreviations as a Lua table.
function abbreviations.load()
  if _MEMOIZED ~= nil then return _MEMOIZED end
  local this_file = debug.getinfo(2, "S").source:sub(2)
  local base_directory = vim.fn.fnamemodify(this_file, ":h:h:h")
  local path = base_directory .. '/vscode-lean/abbreviations.json'
  _MEMOIZED = vim.fn.json_decode(vim.fn.readfile(path))
  return _MEMOIZED
end

--- Retrieve the table of abbreviations that would produce the given symbol.
--
--  Allows for trailing junk. E.g. `λean` will produce information about `λ`.
--
--  The result is a table keyed by the length of the prefix match, and
--  whose value is sorted such that shorter abbreviation suggestions are
--  first.
function abbreviations.reverse_lookup(symbol_plus_unknown)
  local reverse = {}
  for key, value in pairs(abbreviations.load()) do
    if vim.startswith(symbol_plus_unknown, value) then
      reverse[#value] = reverse[#value] or {}
      table.insert(reverse[#value], abbreviations.leader .. key)
    end
  end
  for _, value in pairs(reverse) do
    table.sort(value, function(a, b) return #a < #b or #a == #b and  a < b end)
  end
  return reverse
end

--- Show a preview window with the reverse-lookup of the current character.
function abbreviations.show_reverse_lookup()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local char = vim.api.nvim_get_current_line():sub(col)
  local results = abbreviations.reverse_lookup(char)
  local lines
  if vim.tbl_isempty(results) then
    lines = {
      string.format("No abbreviation found for %q.", char);
      "",
      "Add one by modifying your invocation of:";
      "  require'lean'.setup{ abbreviations = { extra = { ... } } }`";
    }
  else
    lines = {}
    for i=#char, 1, -1 do
      if results[i] ~= nil then
        table.insert(lines, string.format("Type %s with:", char:sub(1, i)))
        for _, each in ipairs(results[i]) do
          table.insert(lines, "  " .. each)
        end
      end
    end
  end
  vim.lsp.util.open_floating_preview(lines)
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

local abbr_mark_ns = vim.api.nvim_create_namespace('lean.abbreviations')

local function get_extmark_range(abbr_ns, id, buffer)
  local row, col, details = unpack(
    vim.api.nvim_buf_get_extmark_by_id(buffer or 0, abbr_ns, id, {details = true}))
  return row, col, details and details.end_row, details and details.end_col
end

---inoremap a key temporarily for the duration of the abbreviation expansion
---@param key string
---@param to string
local function inoremap_temporarily(key, to)
  local imap = vim.fn.maparg(key, "i", false, true)
  if vim.fn.empty(imap) == 0 then
    buf_imaps[key] = {
      rhs = imap.rhs,
      opts = {
        noremap = imap.noremap == 1,
        expr = imap.expr == 1,
        silent = imap.silent == 1,
        nowait = imap.nowait == 1,
        script = imap.script == 1,
      },
    }
  end

  vim.api.nvim_buf_set_keymap(0, 'i', key, to, { noremap = true })
end

local function restore_buf_imaps()
  for k, v in pairs(buf_imaps) do
    if type(v) == 'table' and next(v) then
      vim.api.nvim_buf_set_keymap(0, 'i', k, v.rhs, v.opts)
      buf_imaps[k] = nil
    end
  end
end

local function _clear_abbr_mark()
  vim.api.nvim_buf_del_extmark(0, abbr_mark_ns, abbreviations.abbr_mark)
  abbreviations.abbr_mark = nil
  vim.api.nvim_buf_del_keymap(0, 'i', '<CR>')
  vim.api.nvim_buf_del_keymap(0, 'i', '<Tab>')
  restore_buf_imaps()
end

function abbreviations._insert_char_pre()
  local char = vim.api.nvim_get_vvar('char')

  if abbreviations.abbr_mark then
    if vim.tbl_contains({'{', '}', '(', ')', ' '}, char) then
      return vim.schedule(abbreviations.convert)
    end
  end

  -- typing \\ should result in \ and exit abbreviation mode
  if abbreviations.abbr_mark and char == abbreviations.leader then
    local row1, col1, row2, col2 = get_extmark_range(abbr_mark_ns, abbreviations.abbr_mark)
    if row1 and row1 == row2 then
      local text = vim.api.nvim_buf_get_lines(0, row1, row1+1, true)[1]:sub(col1 + 1, col2)
      if text == abbreviations.leader then
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

  if not abbreviations.abbr_mark and char == abbreviations.leader then
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    row = row - 1
    abbreviations.abbr_mark = vim.api.nvim_buf_set_extmark(0, abbr_mark_ns, row, col, {
      hl_group = 'leanAbbreviationMark',
      end_line = row,
      end_col = col,
      right_gravity = false,
      end_right_gravity = true,
    })
    -- override only for the duration of the abbreviation (clashes with autocompletion plugins)
    inoremap_temporarily('<CR>', [[<C-o>:lua require'lean.abbreviations'.convert()<CR><CR>]])
    inoremap_temporarily('<Tab>', [[<Cmd>lua require'lean.abbreviations'.convert()<CR>]])
  end
end

local function convert_abbrev(abbrev)
  if abbrev:find(abbreviations.leader) ~= 1 then return abbrev end
  abbrev = abbrev:sub(#abbreviations.leader + 1)
  if abbrev:find(abbreviations.leader) == 1 then
    return abbreviations.leader .. convert_abbrev(abbrev:sub(#abbreviations.leader + 1))
  end
  local matchlen, fromlen, repl = 0, 99999, ""
  for from, to in pairs(abbreviations.abbreviations) do
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
  if matchlen == 0 then return abbreviations.leader .. abbrev end
  return repl .. convert_abbrev(abbrev:sub(matchlen + 1))
end

function abbreviations.convert()
  if not abbreviations.abbr_mark then return end
  local row1, col1, row2, col2 = get_extmark_range(abbr_mark_ns, abbreviations.abbr_mark)
  _clear_abbr_mark()
  if not row1 then return end

  local tmp_extmark = vim.api.nvim_buf_set_extmark(0, abbr_mark_ns, row1, col1,
    { end_line = row2, end_col = col2 })

  row1, col1, row2, col2 = get_extmark_range(abbr_mark_ns, tmp_extmark)
  if not row1 or row1 ~= row2 then return end
  vim.api.nvim_buf_del_extmark(0, abbr_mark_ns, tmp_extmark)
  local text = vim.api.nvim_buf_get_lines(0, row1, row1+1, true)[1]:sub(col1 + 1, col2)
  local converted = convert_abbrev(text)

  -- Put the cursor at $CURSOR if it's present, otherwise at the end.
  local new_cursor_col_shift, _ = converted:find('$CURSOR')
  if new_cursor_col_shift then
    converted = converted:gsub('$CURSOR', '')
    new_cursor_col_shift = new_cursor_col_shift - 1
  else
    new_cursor_col_shift = #converted
  end

  vim.api.nvim_buf_set_text(0, row1, col1, row2, col2, {converted})
  vim.api.nvim_win_set_cursor(0, { row1 + 1, col1 + new_cursor_col_shift })
end

local function enable_builtin()
  set_augroup("LeanAbbreviations", [[
    autocmd InsertCharPre *.lean lua require'lean.abbreviations'._insert_char_pre()
    autocmd InsertLeave *.lean lua require'lean.abbreviations'.convert()
    autocmd BufLeave *.lean lua require'lean.abbreviations'.convert()
  ]])
  vim.cmd[[hi def leanAbbreviationMark cterm=underline gui=underline guisp=Gray]]
  -- CursorMoved CursorMovedI as well?
end

function abbreviations.enable(opts)
  abbreviations.leader = opts.leader or '\\'

  abbreviations.abbreviations = abbreviations.load()
  for from, to in pairs(opts.extra or {}) do
    abbreviations.abbreviations[from] = to
  end

  if opts.compe then
    compe_nvim_enable(require('compe'), add_leader(abbreviations.leader, abbreviations.abbreviations))
  end

  if opts.builtin then
    enable_builtin()
  end
end

return abbreviations
