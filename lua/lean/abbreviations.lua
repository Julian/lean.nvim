---@mod lean.abbreviations (Unicode) Abbreviation Expansion

---@brief [[
--- Support for abbreviations (unicode character replacement).
---@brief ]]

local Buffer = require 'std.nvim.buffer'

local abbreviations = {}

---The leader which begins abbreviations.
---@return string leader
local function leader()
  return require 'lean.config'().abbreviations.leader
end

local _MEMOIZED = nil

---Load the Lean abbreviations as a Lua table.
---@return { [string]: string } abbreviations
function abbreviations.load()
  if _MEMOIZED ~= nil then
    return _MEMOIZED
  end
  local this_dir = vim.fs.dirname(debug.getinfo(2, 'S').source:sub(2))
  local path = vim.fs.joinpath(this_dir, '../../vscode-lean/abbreviations.json')
  local file = io.open(path, 'r')
  if not file then
    error(('Unable to read abbreviations from %q'):format(path))
  end
  _MEMOIZED = vim.json.decode(file:read '*a')
  file:close()
  return _MEMOIZED
end

---Retrieve the table of abbreviations that would produce the given symbol.
---
---Allows for trailing junk. E.g. `λean` will produce information about `λ`.
---
---The result is a table keyed by the length of the prefix match, and
---whose value is sorted such that shorter abbreviation suggestions are
---first.
function abbreviations.reverse_lookup(symbol_plus_unknown)
  local lead = leader()
  local reverse = {}
  for key, value in pairs(abbreviations.load()) do
    if vim.startswith(symbol_plus_unknown, value) then
      reverse[#value] = reverse[#value] or {}
      table.insert(reverse[#value], lead .. key)
    end
  end
  for _, value in pairs(reverse) do
    table.sort(value, function(a, b)
      return #a < #b or #a == #b and a < b
    end)
  end
  return reverse
end

---Show a preview window with the reverse-lookup of the current character.
function abbreviations.show_reverse_lookup()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local char = vim.api.nvim_get_current_line():sub(col)
  local results = abbreviations.reverse_lookup(char)
  local lines
  if vim.tbl_isempty(results) then
    lines = {
      string.format('No abbreviation found for %q.', char),
      '',
      'Add one by configuring:\n',
      '  `vim.g.lean_config = { abbreviations = { extra = { ... } } }`',
    }
  else
    lines = {}
    for i = #char, 1, -1 do
      if results[i] ~= nil then
        table.insert(lines, string.format('Type %s with:', char:sub(1, i)))
        for _, each in ipairs(results[i]) do
          table.insert(lines, '  ' .. each)
        end
      end
    end
  end
  vim.lsp.util.open_floating_preview(
    lines,
    'markdown',
    { focus_id = 'lean_abbreviation_help', border = 'rounded' }
  )
end

local abbr_mark_ns = vim.api.nvim_create_namespace 'lean.abbreviations'

local function get_extmark_range(abbr_ns, id, buffer)
  local row, col, details =
    unpack(vim.api.nvim_buf_get_extmark_by_id(buffer or 0, abbr_ns, id, { details = true }))
  return row, col, details and details.end_row, details and details.end_col
end

local function _clear_abbr_mark()
  vim.api.nvim_buf_del_extmark(0, abbr_mark_ns, abbreviations.abbr_mark)
  abbreviations.abbr_mark = nil
  vim.b.cleanup_imaps()
end

local function insert_char_pre()
  local char = vim.v.char
  local lead = leader()

  if abbreviations.abbr_mark then
    if char == ' ' then
      vim.schedule(abbreviations.convert)
      return
    end
  end

  -- typing \\ should result in \ and exit abbreviation mode
  if abbreviations.abbr_mark and char == lead then
    local row1, col1, row2, col2 = get_extmark_range(abbr_mark_ns, abbreviations.abbr_mark)
    if row1 and row1 == row2 then
      local text = vim.api.nvim_buf_get_lines(0, row1, row1 + 1, true)[1]:sub(col1 + 1, col2)
      if text == lead then
        _clear_abbr_mark()
        local tmp_extmark = vim.api.nvim_buf_set_extmark(
          0,
          abbr_mark_ns,
          row1,
          col1,
          { end_line = row2, end_col = col2 }
        )
        vim.schedule(function()
          row1, col1, row2, col2 = get_extmark_range(abbr_mark_ns, tmp_extmark)
          if not row1 then
            return
          end
          vim.api.nvim_buf_del_extmark(0, abbr_mark_ns, tmp_extmark)
          vim.api.nvim_buf_set_text(0, row1, col1, row2, col2, {})
        end)
        return
      end
    end
  end

  if not abbreviations.abbr_mark and char == lead then
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    row = row - 1
    abbreviations.abbr_mark = vim.api.nvim_buf_set_extmark(0, abbr_mark_ns, row, col, {
      hl_group = 'leanAbbreviationMark',
      end_line = row,
      end_col = col,
      right_gravity = false,
      end_right_gravity = true,
    })

    local mappings = {
      ['<CR>'] = [[<C-o>:lua require'lean.abbreviations'.convert()<CR><CR>]],
      ['<Tab>'] = [[<Cmd>lua require'lean.abbreviations'.convert()<CR>]],
    }

    local buf = Buffer:current()
    local cleanups = vim.defaulttable(function(key)
      return function()
        buf.keymaps:del('i', key)
      end
    end)

    for imap in vim.iter(buf.keymaps:get 'i') do
      local lhs = imap.lhs
      local rhs = imap.rhs or ''
      if mappings[lhs] then
        cleanups[lhs] = function()
          vim.api.nvim_buf_set_keymap(buf.bufnr, 'i', lhs, rhs, {
            nowait = imap.nowait,
            silent = imap.silent,
            script = imap.script,
            expr = imap.expr,
            unique = imap.unique,
            callback = imap.callback,
            desc = imap.desc,
          })
        end
      end
    end

    for key, to in vim.iter(mappings) do
      buf.keymaps:set('i', key, to)
    end

    vim.b.cleanup_imaps = function()
      vim.iter(mappings):each(function(key)
        cleanups[key]()
      end)
      vim.b.cleanup_imaps = function() end
    end
  end
end

local function cmdwin_enter()
  local came_from = vim.api.nvim_win_get_buf(vim.fn.win_getid(vim.fn.winnr '#'))
  if vim.bo[came_from].filetype ~= 'lean' then
    return
  end

  local augroup = vim.api.nvim_create_augroup('LeanAbbreviationCmdwin', {})
  vim.api.nvim_create_autocmd('InsertCharPre', {
    group = augroup,
    buffer = 0,
    callback = insert_char_pre,
  })
  vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufLeave' }, {
    group = augroup,
    buffer = 0,
    callback = abbreviations.convert,
  })
end

local function cmdwin_leave()
  vim.api.nvim_create_augroup('LeanAbbreviationCmdwin', {})
end

---All known abbreviations, including any extra user-configured ones.
---@return { [string]: string } abbreviations
local function all_abbreviations()
  return vim.tbl_extend('force', abbreviations.load(), require 'lean.config'().abbreviations.extra)
end

---@param lead string the abbreviation leader
---@param all { [string]: string } the abbreviations to expand with
---@param abbrev string the typed text to convert
local function convert_abbrev(lead, all, abbrev)
  if abbrev:find(lead) ~= 1 then
    return abbrev
  end
  abbrev = abbrev:sub(#lead + 1)
  if abbrev:find(lead) == 1 then
    return lead .. convert_abbrev(lead, all, abbrev:sub(#lead + 1))
  end
  local matchlen, fromlen, repl = 0, 99999, ''
  for from, to in pairs(all) do
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
  if matchlen == 0 then
    return lead .. abbrev
  end
  return repl .. convert_abbrev(lead, all, abbrev:sub(matchlen + 1))
end

---Convert any abbreviation currently being typed at the cursor.
function abbreviations.convert()
  if not abbreviations.abbr_mark then
    return
  end
  local row1, col1, row2, col2 = get_extmark_range(abbr_mark_ns, abbreviations.abbr_mark)
  _clear_abbr_mark()
  if not row1 then
    return
  end

  local tmp_extmark =
    vim.api.nvim_buf_set_extmark(0, abbr_mark_ns, row1, col1, { end_line = row2, end_col = col2 })

  row1, col1, row2, col2 = get_extmark_range(abbr_mark_ns, tmp_extmark)
  if not row1 or row1 ~= row2 then
    return
  end
  vim.api.nvim_buf_del_extmark(0, abbr_mark_ns, tmp_extmark)
  local text = vim.api.nvim_buf_get_lines(0, row1, row1 + 1, true)[1]:sub(col1 + 1, col2)
  local converted = convert_abbrev(leader(), all_abbreviations(), text)

  -- Put the cursor at $CURSOR if it's present, otherwise at the end.
  local new_cursor_col_shift, _ = converted:find '$CURSOR'
  if new_cursor_col_shift then
    converted = converted:gsub('$CURSOR', '')
    new_cursor_col_shift = new_cursor_col_shift - 1
  else
    new_cursor_col_shift = #converted
  end

  vim.api.nvim_buf_set_text(0, row1, col1, row2, col2, { converted })
  vim.api.nvim_win_set_cursor(0, { row1 + 1, col1 + new_cursor_col_shift })
end

local EVENTS = {
  InsertCharPre = insert_char_pre,
  InsertLeave = abbreviations.convert,
  BufLeave = abbreviations.convert,
}

local initialized = false

---One-time global setup shared by every buffer with abbreviation support.
local function global_init()
  if initialized then
    return
  end
  initialized = true

  local augroup = vim.api.nvim_create_augroup('LeanAbbreviations', { clear = false })
  vim.api.nvim_create_autocmd('CmdwinEnter', { group = augroup, callback = cmdwin_enter })
  vim.api.nvim_create_autocmd('CmdwinLeave', { group = augroup, callback = cmdwin_leave })
  vim.api.nvim_set_hl(0, 'leanAbbreviationMark', { default = true, underline = true, sp = 'Gray' })
end

---Set up abbreviation expansion in the given (Lean) buffer.
---
---Runs automatically via our Lean ftplugin, i.e. lazily when opening Lean
---buffers.
---@param bufnr integer
function abbreviations.init(bufnr)
  if require 'lean.config'().abbreviations.enable == false then
    return
  end
  global_init()

  local augroup = vim.api.nvim_create_augroup('LeanAbbreviations', { clear = false })
  vim.api.nvim_clear_autocmds { group = augroup, buffer = bufnr }
  for event, callback in pairs(EVENTS) do
    vim.api.nvim_create_autocmd(event, {
      group = augroup,
      buffer = bufnr,
      callback = callback,
    })
  end
end

---Enable abbreviation expansion for buffers matching the given pattern.
---
---Lean buffers have abbreviations enabled automatically; this can be used to
---also enable them for other buffers (e.g. `*.md` or `*.txt` files).
---@param pattern string|string[] an autocommand pattern to match against
function abbreviations.enable(pattern)
  global_init()

  local augroup = vim.api.nvim_create_augroup('LeanAbbreviations', { clear = false })
  for event, callback in pairs(EVENTS) do
    vim.api.nvim_create_autocmd(event, {
      group = augroup,
      pattern = pattern,
      callback = callback,
    })
  end
end

return abbreviations
