local lean = {lsp = {}, abbreviations = require('lean.abbreviations')}

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

return lean
