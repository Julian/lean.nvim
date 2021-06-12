local lean = {
  lsp = require('lean.lsp'),
  abbreviations = require('lean.abbreviations'),

  mappings = {
    n = {
      ["<LocalLeader>i"] = "<Cmd>lua require('lean.infoview').toggle()<CR>";
      ["<LocalLeader>s"] = "<Cmd>lua require('lean.sorry').fill()<CR>";
      ["<LocalLeader>t"] = "<Cmd>lua require('lean.trythis').swap()<CR>";
      ["<LocalLeader>3"] = "<Cmd>lua require('lean.lean3').init()<CR>";
    };
    i = {
    };
  }
}

function lean.setup(opts)
  opts = opts or {}

  opts.abbreviations = opts.abbreviations or {}
  if opts.abbreviations.enable ~= false then lean.abbreviations.enable(opts.abbreviations) end

  opts.infoview = opts.infoview or {}
  if opts.infoview.enable ~= false then require('lean.infoview').enable(opts.infoview) end

  opts.lsp3 = opts.lsp3 or {}
  if opts.lsp3.enable ~= false then require('lspconfig').lean3ls.setup(opts.lsp3) end

  opts.lsp = opts.lsp or {}
  if opts.lsp.enable ~= false then lean.lsp.enable(opts.lsp) end

  opts.treesitter = opts.treesitter or {}
  if opts.treesitter.enable ~= false then require('lean.treesitter').enable(opts.treesitter) end

  if opts.mappings == true then
    vim.api.nvim_exec([[
      autocmd FileType lean3 lua require'lean'.use_suggested_mappings(true)
      autocmd FileType lean lua require'lean'.use_suggested_mappings(true)
    ]], false)
  end

  -- needed for testing
  lean.config = opts
end

function lean.use_suggested_mappings(buffer_local)
  local opts = { noremap = true }
  for mode, mode_mappings in pairs(lean.mappings) do
    for lhs, rhs in pairs(mode_mappings) do
      if buffer_local then
        vim.api.nvim_buf_set_keymap(0, mode, lhs, rhs, opts)
      else
        vim.api.nvim_set_keymap(mode, lhs, rhs, opts)
      end
    end
  end
end

return lean
