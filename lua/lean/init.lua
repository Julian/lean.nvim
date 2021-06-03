local lean = {
  lsp = require('lean.lsp'),
  abbreviations = require('lean.abbreviations'),
}

function lean.setup(opts)
  opts = opts or {}


  local abbreviations = opts.abbreviations or {}
  if abbreviations.enable ~= false then lean.abbreviations.enable(abbreviations) end

  local treesitter = opts.treesitter or {}
  if treesitter.enable ~= false then require('lean.treesitter').enable(treesitter) end

  local lsp3 = opts.lsp3 or {}
  if lsp3.enable ~= false then lean.lsp.enable(lsp3) end

  local lsp4 = opts.lsp4 or {}
  if lsp4.enable ~= false then lean.lsp.enable4(lsp4) end

  local infoview = opts.infoview or {}
  if infoview.enable ~= false then
    if opts.info_pertab then vim.g.lean_info_pertab = true else vim.g.lean_info_pertab = false end
    require('lean.infoview').enable(infoview)
  end

  if opts.mappings == true then lean.use_suggested_mappings() end
end

function lean.use_suggested_mappings()
  local opts = {noremap = true, silent = true}
  vim.api.nvim_set_keymap(
    'n', '<LocalLeader>3', "<Cmd>lua require('lean.lean3').init()<CR>", opts
  )
  vim.api.nvim_set_keymap(
    'n', '<LocalLeader>i', "<Cmd>lua require('lean.infoview').toggle()<CR>", opts
  )
  vim.api.nvim_set_keymap(
    'n', '<LocalLeader>s', "<Cmd>lua require('lean.sorry').fill()<CR>", opts
  )
  vim.api.nvim_set_keymap(
    'n', '<LocalLeader>t', "<Cmd>lua require('lean.trythis').swap()<CR>", opts
  )
end

return lean
