local abbreviations = {}

--- Load the Lean abbreviations as a Lua table.
function abbreviations.load()
  local this_file = debug.getinfo(2, "S").source:sub(2)
  local base_directory = vim.fn.fnamemodify(this_file, ":h:h:h")
  local path = base_directory .. '/vscode-lean/abbreviations.json'
  local lean_abbreviations = {}
  for from, to in pairs(vim.fn.json_decode(vim.fn.readfile(path))) do
    lean_abbreviations["\\" .. from] = to
  end
  return lean_abbreviations
end

local function compe_nvim_enable(compe, lean_abbreviations)
  local Source = require'lean._compe'.new(lean_abbreviations)
  compe.register_source('lean_abbreviations', Source)

  local Config = require('compe.config').get()
  Config.source = Config.source or {}
  Config.source['lean_abbreviations'] = { disabled = false }
end

local function snippets_nvim_enable(snippets, lean_abbreviations)
  local all_snippets = snippets.snippets or {}
  all_snippets.lean = lean_abbreviations
  snippets.snippets = all_snippets
end

function abbreviations.enable(opts)
  local lean_abbreviations = abbreviations.load()

  for from, to in pairs(opts.extra or {}) do
    abbreviations["\\" .. from] = to
  end

  local has_snippets, snippets = pcall(require, 'snippets')
  if has_snippets then snippets_nvim_enable(snippets, lean_abbreviations) end

  local has_compe, compe = pcall(require, 'compe')
  if has_compe then compe_nvim_enable(compe, lean_abbreviations) end
end

return abbreviations
