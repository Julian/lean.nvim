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
  all_snippets.lean = lean_abbreviations
  snippets.snippets = all_snippets
end

function M.enable(opts)
  local leader = opts.leader or '\\'

  local lean_abbreviations = M.load()
  for from, to in pairs(opts.extra or {}) do
    lean_abbreviations[from] = to
  end

  if opts.snippets then
    snippets_nvim_enable(require('snippets'), add_leader(leader, lean_abbreviations))
  end

  if opts.compe then
    compe_nvim_enable(require('compe'), add_leader(leader, lean_abbreviations))
  end
end

return M
