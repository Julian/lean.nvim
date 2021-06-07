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

  local abbreviations = opts.abbreviations or {}
  if abbreviations.enable ~= false then lean.abbreviations.enable(abbreviations) end

  local infoview = opts.infoview or {}
  if infoview.enable ~= false then require('lean.infoview').enable(infoview) end

  local lsp = opts.lsp or {}
  if lsp.enable ~= false then lean.lsp.enable(lsp) end

  local treesitter = opts.treesitter or {}
  if treesitter.enable ~= false then require('lean.treesitter').enable(treesitter) end

  if opts.mappings == true then
    vim.api.nvim_exec([[
      autocmd FileType lean lua require'lean'.use_suggested_mappings(true)
    ]], false)
  end
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
