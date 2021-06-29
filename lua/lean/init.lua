---@brief [[
--- lean.nvim is a plugin providing Neovim support for the Lean interactive
--- theorem prover, developed by Leonardo de Moura at Microsoft Research.
---
--- To find out more, see https://github.com/Julian/lean.nvim.
---@brief ]]

---@tag lean.nvim

local lean = {
  lsp = require('lean.lsp'),
  abbreviations = require('lean.abbreviations'),

  mappings = {
    n = {
      ["<LocalLeader>i"] = "<Cmd>lua require('lean.infoview').toggle()<CR>";
      ["<LocalLeader>s"] = "<Cmd>lua require('lean.sorry').fill()<CR>";
      ["<LocalLeader>t"] = "<Cmd>lua require('lean.trythis').swap()<CR>";
      ["<LocalLeader>3"] = "<Cmd>lua require('lean.lean3').init()<CR>";
      ["<LocalLeader>\\"] = "<Cmd>lua require('lean.abbreviations').show_reverse_lookup()<CR>";
    };
    i = {
    };
  }
}

--- Setup function to be run in your init.lua (or init.vim).
---@param opts table: Configuration options
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

  opts.progress_bars = opts.progress_bars or {}
  if opts.progress_bars ~= false then require'lean.progress_bars'.enable(opts.progress_bars) end

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
