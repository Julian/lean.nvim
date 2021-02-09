local lean = {lsp = {}, abbreviations = {}}

function lean.setup(opts)
  opts = opts or {}

  local abbreviations = opts.abbreviations or {}
  if abbreviations.enable ~= false then lean.abbreviations.enable(abbreviations) end

  local lsp = opts.lsp or {}
  if lsp.enable ~= false then lean.lsp.enable(lsp) end
end

function lean.lsp.enable(opts)
  require('lspconfig').leanls.setup(opts)
end

--- Load the Lean abbreviations as a Lua table.
function lean.abbreviations.load()
  local this_file = debug.getinfo(2, "S").source:sub(2)
  local base_directory = vim.fn.fnamemodify(this_file, ":h:h:h")
  local path = base_directory .. '/vscode-lean/abbreviations.json'
  local abbreviations = {}
  for from, to in pairs(vim.fn.json_decode(vim.fn.readfile(path))) do
    abbreviations["\\" .. from] = to
  end
  return abbreviations
end

function lean.abbreviations.enable(opts)
  local abbreviations = lean.abbreviations.load()

  for from, to in pairs(opts.extra or {}) do
    abbreviations["\\" .. from] = to
  end

  local snippets = require('snippets')
  local all_snippets = snippets.snippets or {}

  all_snippets.lean = abbreviations
  snippets.snippets = all_snippets
end

return lean
