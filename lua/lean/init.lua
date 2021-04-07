local lean = {
  lsp = require('lean.lsp'),
  abbreviations = require('lean.abbreviations'),
}

function lean.setup(opts)
  opts = opts or {}

  local abbreviations = opts.abbreviations or {}
  if abbreviations.enable ~= false then lean.abbreviations.enable(abbreviations) end

  local lsp = opts.lsp or {}
  if lsp.enable ~= false then lean.lsp.enable(lsp) end

  local treesitter = opts.treesitter or {}
  if treesitter.enable ~= false then require('lean.treesitter').enable(treesitter) end

  if opts.mappings == true then lean.use_suggested_mappings() end
end

function lean.use_suggested_mappings()
  local opts = {noremap = true, silent = true}
  vim.api.nvim_set_keymap(
    'n', '<LocalLeader>s', "<Cmd>lua require('lean.sorry').fill()<CR>", opts
  )
  vim.api.nvim_set_keymap(
    'n', '<LocalLeader>t', "<Cmd>lua require('lean.trythis').swap()<CR>", opts
  )
end

return lean
