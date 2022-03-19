---@brief [[
--- lean.nvim is a plugin providing Neovim support for the Lean interactive
--- theorem prover, developed by Leonardo de Moura at Microsoft Research.
---
--- To find out more, see https://github.com/Julian/lean.nvim.
---@brief ]]

---@tag lean.nvim
local util = require('lean._util')

local subprocess_check_output = util.subprocess_check_output

local lean = {
  mappings = {
    n = {
      ['<LocalLeader>i'] = '<Cmd>LeanInfoviewToggle<CR>';
      ['<LocalLeader>p'] = '<Cmd>LeanInfoviewPinTogglePause<CR>';
      ['<LocalLeader>x'] = '<Cmd>LeanInfoviewAddPin<CR>';
      ['<LocalLeader>c'] = '<Cmd>LeanInfoviewClearPins<CR>';
      ['<LocalLeader>dx'] = '<Cmd>LeanInfoviewSetDiffPin<CR>';
      ['<LocalLeader>dc'] = '<Cmd>LeanInfoviewClearDiffPin<CR>';
      ['<LocalLeader>dd'] = '<Cmd>LeanInfoviewToggleAutoDiffPin<CR>';
      ['<LocalLeader>dt'] = '<Cmd>LeanInfoviewToggleNoClearAutoDiffPin<CR>';
      ['<LocalLeader>w'] = '<Cmd>LeanInfoviewEnableWidgets<CR>';
      ['<LocalLeader>W'] = '<Cmd>LeanInfoviewDisableWidgets<CR>';
      ['<LocalLeader><Tab>'] = '<Cmd>LeanGotoInfoview<CR>';
      ['<LocalLeader>s'] = '<Cmd>LeanSorryFill<CR>';
      ['<LocalLeader>t'] = '<Cmd>LeanTryThis<CR>';
      ['<LocalLeader>\\'] = '<Cmd>LeanAbbreviationsReverseLookup<CR>';
    };
    i = {
    };
  };
}

--- Setup function to be run in your init.lua (or init.vim).
---@param opts table: Configuration options
function lean.setup(opts)
  opts = opts or {}

  opts.abbreviations = opts.abbreviations or {}
  if opts.abbreviations.enable ~= false then require'lean.abbreviations'.enable(opts.abbreviations) end

  opts.infoview = opts.infoview or {}
  require'lean.infoview'.enable(opts.infoview)

  require'lean.commands'.enable()

  opts.lsp3 = opts.lsp3 or {}
  if opts.lsp3.enable ~= false then require'lean.lean3'.lsp_enable(opts.lsp3) end

  opts.lsp = opts.lsp or {}
  if opts.lsp.enable ~= false then require'lean.lsp'.enable(opts.lsp) end

  opts.treesitter = opts.treesitter or {}
  if opts.treesitter.enable ~= false then require'lean.treesitter'.enable(opts.treesitter) end

  opts.progress_bars = opts.progress_bars or {}
  if opts.progress_bars.enable ~= false then require'lean.progress_bars'.enable(opts.progress_bars) end

  require'lean.ft'.enable(opts.ft or {})

  if not opts.stderr or opts.stderr.enable then
    require'lean.stderr'.enable()
  end

  vim.cmd[[
    command LeanInfoviewToggle :lua require'lean.infoview'.toggle()
    command LeanInfoviewPinTogglePause :lua require'lean.infoview'.pin_toggle_pause()
    command LeanInfoviewAddPin :lua require'lean.infoview'.add_pin()
    command LeanInfoviewClearPins :lua require'lean.infoview'.clear_pins()
    command LeanInfoviewSetDiffPin :lua require'lean.infoview'.set_diff_pin()
    command LeanInfoviewClearDiffPin :lua require'lean.infoview'.clear_diff_pin()
    command LeanInfoviewToggleAutoDiffPin :lua require'lean.infoview'.toggle_auto_diff_pin(true)
    command LeanInfoviewToggleNoClearAutoDiffPin :lua require'lean.infoview'.toggle_auto_diff_pin(false)
    command LeanInfoviewEnableWidgets :lua require'lean.infoview'.enable_widgets()
    command LeanInfoviewDisableWidgets :lua require'lean.infoview'.disable_widgets()
    command LeanGotoInfoview :lua require'lean.infoview'.go_to()

    command LeanAbbreviationsReverseLookup :lua require'lean.abbreviations'.show_reverse_lookup()

    command LeanSorryFill :lua require'lean.sorry'.fill()
    command LeanTryThis :lua require'lean.trythis'.swap()
  ]]

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
  local buffer = buffer_local and 0
  util.load_mappings(lean.mappings, buffer)
end

--- Is the current buffer a lean buffer?
function lean.is_lean_buffer()
  local filetype = vim.opt.filetype:get()
  return filetype == "lean" or filetype == "lean3"
end

--- Is the current buffer a lean 3 buffer?
function lean.is_lean3_buffer()
  return vim.opt.filetype:get() == "lean3"
end

--- Return the current Lean search path.
---
--- Includes both the Lean core libraries as well as project-specific
--- directories.
function lean.current_search_paths()
  local paths

  if lean.is_lean3_buffer() then
    paths = require'lean.lean3'.__current_search_paths()
  else
    local root = util.list_workspace_folders()[1]
    if not root then root = vim.fn.getcwd() end

    local executable = (
        vim.loop.fs_stat(root .. '/' .. 'lakefile.lean')
         or not vim.loop.fs_stat(root .. '/' .. 'leanpkg.toml')
    ) and "lake" or "leanpkg"

    local all_paths = vim.fn.json_decode(
      subprocess_check_output{
        command = executable, args = {"print-paths"}, cwd = root
    })
    paths = vim.tbl_map(function(path) return root .. '/' .. path end, all_paths.srcPath)
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
