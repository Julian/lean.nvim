---@brief [[
--- lean.nvim is a plugin providing Neovim support for the Lean interactive
--- theorem prover, developed by Leonardo de Moura at Microsoft Research.
---
--- To find out more, see https://github.com/Julian/lean.nvim.
---@brief ]]

---@tag lean.nvim

local subprocess_check_output = require('lean._util').subprocess_check_output

local lean = {
  mappings = {
    n = {
      ["<LocalLeader>i"] = "<Cmd>lua require'lean.infoview'.get_current_infoview():toggle()<CR>";
      ["<LocalLeader>s"] = "<Cmd>lua require'lean.sorry'.fill()<CR>";
      ["<LocalLeader>t"] = "<Cmd>lua require'lean.trythis'.swap()<CR>";
      ["<LocalLeader>\\"] = "<Cmd>lua require'lean.abbreviations'.show_reverse_lookup()<CR>";
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
  if opts.abbreviations.enable ~= false then require'lean.abbreviations'.enable(opts.abbreviations) end

  opts.infoview = opts.infoview or {}
  require'lean.infoview'.enable(opts.infoview)

  opts.lsp3 = opts.lsp3 or {}
  if opts.lsp3.enable ~= false then require'lspconfig'.lean3ls.setup(opts.lsp3) end

  opts.lsp = opts.lsp or {}
  if opts.lsp.enable ~= false then require'lean.lsp'.enable(opts.lsp) end

  opts.treesitter = opts.treesitter or {}
  if opts.treesitter.enable ~= false then require'lean.treesitter'.enable(opts.treesitter) end

  opts.progress_bars = opts.progress_bars or {}
  if opts.progress_bars.enable ~= false then require'lean.progress_bars'.enable(opts.progress_bars) end

  if opts.mappings == true then
    vim.cmd[[
      autocmd FileType lean3 lua require'lean'.use_suggested_mappings(true)
      autocmd FileType lean lua require'lean'.use_suggested_mappings(true)
    ]]
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

--- Is the current buffer a lean buffer?
function lean.is_lean_buffer()
  local filetype = vim.opt.filetype:get()
  return filetype == "lean" or filetype == "lean3"
end

--- Return the current Lean search path.
---
--- Includes both the Lean core libraries as well as project-specific
--- directories.
function lean.current_search_paths()
  local paths

  if vim.opt.filetype:get() == "lean3" then
    paths = require'lean.lean3'.__current_search_paths()
  else
    local root = vim.lsp.buf.list_workspace_folders()[1]
    -- print-paths emits a colon-separated list of .lean paths on the second line
    local all_paths = subprocess_check_output(
      { command = "leanpkg", args = {"print-paths"}, cwd = root }
    )[2]

    paths = vim.tbl_map(
      function(path) return root .. '/' .. path end,
      vim.split(all_paths, ':')
    )
    vim.list_extend(
      paths,
      subprocess_check_output{ command = "lean", args = {"--print-libdir"}, cwd = root }
    )
  end

  return vim.tbl_map(
    vim.fn.simplify,
    vim.tbl_filter(function(path) return path ~= "" and require("lspconfig.util").path.is_dir(path) end, paths)
  )
end

return lean
