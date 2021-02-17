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

local function snippets_nvim_enable(lean_abbreviations)
  local has_snippets, snippets = pcall(require, 'snippets')
  if not has_snippets then return end

  local all_snippets = snippets.snippets or {}
  all_snippets.lean = lean_abbreviations
  snippets.snippets = all_snippets
end

function abbreviations.enable(opts)
  local lean_abbreviations = abbreviations.load()

  for from, to in pairs(opts.extra or {}) do
    abbreviations["\\" .. from] = to
  end

  snippets_nvim_enable(lean_abbreviations)
end

return abbreviations
