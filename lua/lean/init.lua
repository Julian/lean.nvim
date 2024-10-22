---@toc lean

---@mod lean.init Introduction

---@brief [[
--- lean.nvim provides first-class Neovim support for the Lean interactive
--- theorem prover, developed by Leonardo de Moura and the Lean FRO.
---
--- To find out more, see https://github.com/Julian/lean.nvim.
---@brief ]]

---@tag lean.nvim

local has_satellite = require 'lean.satellite'
local subprocess_check_output = require('lean._util').subprocess_check_output

local lean = {
  mappings = {
    {
      '<LocalLeader>i',
      '<Cmd>LeanInfoviewToggle<CR>',
      { desc = 'Toggle showing the infoview.' },
    },
    {
      '<LocalLeader>p',
      '<Cmd>LeanInfoviewPinTogglePause<CR>',
      { desc = 'Toggle pausing infoview pins.' },
    },
    {
      '<LocalLeader>x',
      '<Cmd>LeanInfoviewAddPin<CR>',
      { desc = 'Add an infoview pin.' },
    },
    {
      '<LocalLeader>c',
      '<Cmd>LeanInfoviewClearPins<CR>',
      { desc = 'Clear all infoview pins.' },
    },
    {
      '<LocalLeader>dx',
      '<Cmd>LeanInfoviewSetDiffPin<CR>',
      { desc = 'Set an infoview diff pin.' },
    },
    {
      '<LocalLeader>dc',
      '<Cmd>LeanInfoviewClearDiffPin<CR>',
      { desc = 'Clear all infoview diff pins.' },
    },
    {
      '<LocalLeader>dd',
      '<Cmd>LeanInfoviewToggleAutoDiffPin<CR>',
      { desc = 'Toggle "auto-diff" mode in the infoview.' },
    },
    {
      '<LocalLeader>dt',
      '<Cmd>LeanInfoviewToggleNoClearAutoDiffPin<CR>',
      { desc = 'Toggle "auto-diff" mode and clear any existing pins.' },
    },
    {
      '<LocalLeader>w',
      '<Cmd>LeanInfoviewEnableWidgets<CR>',
      { desc = 'Enable infoview widgets.' },
    },
    {
      '<LocalLeader>W',
      '<Cmd>LeanInfoviewDisableWidgets<CR>',
      { desc = 'Disable infoview widgets.' },
    },
    {
      '<LocalLeader>v',
      '<Cmd>LeanInfoviewViewOptions<CR>',
      { desc = 'Change the infoview view options.' },
    },
    {
      '<LocalLeader><Tab>',
      '<Cmd>LeanGotoInfoview<CR>',
      { desc = 'Jump to the current infoview.' },
    },
    {
      '<LocalLeader>\\',
      '<Cmd>LeanAbbreviationsReverseLookup<CR>',
      { desc = 'Show how to type the unicode character under the cursor.' },
    },
    {
      '<LocalLeader>r',
      '<Cmd>LeanRestartFile<CR>',
      { desc = 'Restart the Lean server for the current file.' },
    },
  },
}

vim.filetype.add { extension = { lean = 'lean' } }

---Setup function to be run in your init.lua (or init.vim).
---@param opts lean.Config: Configuration options
function lean.setup(opts)
  opts = opts or {}

  opts.abbreviations = opts.abbreviations or {}
  if opts.abbreviations.enable ~= false then
    require('lean.abbreviations').enable('*.lean', opts.abbreviations)
  end

  opts.infoview = opts.infoview or {}
  require('lean.infoview').enable(opts.infoview)

  opts.lsp = opts.lsp or {}
  if opts.lsp.enable ~= false then
    require('lean.lsp').enable(opts.lsp)
  end

  opts.progress_bars = opts.progress_bars or {}
  -- FIXME: Maybe someone eventually cares about enabling both.
  if not has_satellite and opts.progress_bars.enable ~= false then
    require('lean.progress_bars').enable(opts.progress_bars)
  end

  opts.stderr = opts.stderr or {}
  if opts.stderr.enable ~= false then
    require('lean.stderr').enable(opts.stderr or {})
  end

  local ok, telescope = pcall(require, 'telescope')
  if ok then
    telescope.load_extension 'loogle'
  end

  vim.cmd [[
    command! LeanRestartFile :lua require'lean.lsp'.restart_file()
    command! LeanRefreshFileDependencies :lua require'lean.lsp'.restart_file()

    command! LeanPlainGoal :lua require'lean.commands'.show_goal(false)
    command! LeanPlainTermGoal :lua require'lean.commands'.show_term_goal(false)
    command! LeanGoal :lua require'lean.commands'.show_goal()
    command! LeanTermGoal :lua require'lean.commands'.show_term_goal()
    command! LeanLineDiagnostics :lua require'lean.commands'.show_line_diagnostics()

    command! LeanGotoInfoview :lua require'lean.infoview'.go_to()
    command! LeanInfoviewToggle :lua require'lean.infoview'.toggle()

    command! LeanInfoviewViewOptions :lua require'lean.infoview'.select_view_options()

    command! LeanInfoviewPinTogglePause :lua require'lean.infoview'.pin_toggle_pause()
    command! LeanInfoviewAddPin :lua require'lean.infoview'.add_pin()
    command! LeanInfoviewClearPins :lua require'lean.infoview'.clear_pins()

    command! LeanInfoviewSetDiffPin :lua require'lean.infoview'.set_diff_pin()
    command! LeanInfoviewClearDiffPin :lua require'lean.infoview'.clear_diff_pin()
    command! LeanInfoviewToggleAutoDiffPin :lua require'lean.infoview'.toggle_auto_diff_pin(true)
    command! LeanInfoviewToggleNoClearAutoDiffPin :lua require'lean.infoview'.toggle_auto_diff_pin(false)

    command! LeanInfoviewEnableWidgets :lua require'lean.infoview'.enable_widgets()
    command! LeanInfoviewDisableWidgets :lua require'lean.infoview'.disable_widgets()

    command! LeanAbbreviationsReverseLookup :lua require'lean.abbreviations'.show_reverse_lookup()

    command! LeanSorryFill :lua require'lean.sorry'.fill()
  ]]

  vim.g.lean_config = opts
end

---Enable mappings for a given buffer
---@param bufnr? number the bufnr to enable mappings in, defaulting to 0
function lean.use_suggested_mappings(bufnr)
  local opts = { buffer = bufnr or 0 }
  for _, each in ipairs(lean.mappings) do
    local lhs, rhs, more_opts = unpack(each)
    vim.keymap.set(each.mode or 'n', lhs, rhs, vim.tbl_extend('error', opts, more_opts))
  end
end

---Return the current Lean search path.
---
---Includes both the Lean core libraries as well as project-specific
---directories.
function lean.current_search_paths()
  local paths

  local root = vim.lsp.buf.list_workspace_folders()[1]
  if not root then
    root = vim.fn.getcwd()
  end

  local all_paths = vim.fn.json_decode(subprocess_check_output {
    command = 'lake',
    args = { 'setup-file', vim.api.nvim_buf_get_name(0) },
    cwd = root,
  })
  paths = vim.tbl_map(function(path)
    return root .. '/' .. path
  end, all_paths.paths.srcPath)
  vim.list_extend(
    paths,
    subprocess_check_output { command = 'lean', args = { '--print-libdir' }, cwd = root }
  )

  return vim.tbl_map(
    vim.fn.simplify,
    vim.tbl_filter(function(path)
      return path ~= '' and vim.uv.fs_stat(path).type == 'directory'
    end, paths)
  )
end

return lean
