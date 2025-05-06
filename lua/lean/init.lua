---@toc lean

---@mod lean.init Introduction

---@brief [[
--- lean.nvim provides first-class Neovim support for the Lean interactive
--- theorem prover, developed by Leonardo de Moura and the Lean FRO.
---
--- To find out more, see https://github.com/Julian/lean.nvim.
---@brief ]]

---@tag lean.nvim

local check_output = require('std.subprocess').check_output

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

---Setup function to be run in your init.lua.
---@param opts lean.Config Configuration options
function lean.setup(opts)
  opts = opts or {}

  opts.abbreviations = opts.abbreviations or {}
  if opts.abbreviations.enable ~= false then
    require('lean.abbreviations').enable('*.lean', opts.abbreviations)
  end

  if opts.infoview and opts.infoview.goal_markers then
    vim.deprecate(
      'lean.setup { infoview = { goal_markers = { ... } } }',
      'lean.setup { goal_markers = { ... } }',
      'v2025.10.1',
      'lean.nvim',
      false
    )
    opts.goal_markers = opts.infoview.goal_markers
    opts.infoview.goal_markers = nil
  end

  opts.infoview = opts.infoview or {}
  require('lean.infoview').enable(opts.infoview)

  opts.lsp = opts.lsp or {}
  if opts.lsp.enable ~= false then
    require('lean.lsp').enable(opts.lsp)
  end

  opts.progress_bars = opts.progress_bars or {}
  if opts.progress_bars.enable ~= false then
    require('lean.progress_bars').enable(opts.progress_bars)
  end

  opts.stderr = opts.stderr or {}
  if opts.stderr.enable ~= false then
    require('lean.stderr').enable(opts.stderr or {})
  end

  local ok, telescope = pcall(require, 'telescope')
  if ok then
    telescope.load_extension 'lean_abbreviations'
    telescope.load_extension 'loogle'
  end

  vim.cmd [[
    command! LeanRestartFile :lua require'lean.lsp'.restart_file()
    command! LeanRefreshFileDependencies :lua require'lean.lsp'.restart_file()

    command! LeanGoal :lua require'lean.commands'.show_goal()
    command! LeanTermGoal :lua require'lean.commands'.show_term_goal()
    command! LeanLineDiagnostics :lua require'lean.commands'.show_line_diagnostics()

    command! LeanPlainGoal :lua require'lean.commands'.show_goal(false)
    command! LeanPlainTermGoal :lua require'lean.commands'.show_term_goal(false)
    command! LeanPlainDiagnostics :lua require'lean.commands'.show_line_diagnostics(false)

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

---Try to find what version of `lean.nvim` this is.
---
---Assumes your `lean.nvim` comes from a `git` repository.
---@return string|nil version
function lean.plugin_version()
  local this_file = debug.getinfo(1, 'S').source:sub(2)
  local lean_nvim_root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(this_file)))
  local git = vim.fs.joinpath(lean_nvim_root, '.git')
  local result = vim.system({ 'git', '--git-dir', git, 'describe', '--tags', '--always' }):wait()
  if result.code == 0 then
    return vim.trim(result.stdout)
  end
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
---@return string[] paths the current Lean search path
function lean.current_search_paths()
  local root = vim.lsp.buf.list_workspace_folders()[1]
  if not root then
    root = vim.fn.getcwd()
  end

  local prefix = vim.trim(check_output({ 'lean', '--print-prefix' }, { cwd = root }))

  local paths = { vim.fs.joinpath(prefix, 'src/lean') }
  local result = vim
    .system({ 'lake', 'setup-file', vim.api.nvim_buf_get_name(0) }, { cwd = root })
    :wait()
  if result.code == 0 then
    vim.list_extend(paths, vim.json.decode(result.stdout).paths.srcPath)
  end

  return vim
    .iter(paths)
    :map(function(path)
      -- Sigh. `vim.fs.joinpath` does not do the right thing with absolute paths.
      -- "Interestingly", while Python and Rust get this right, JS seems not to.
      -- So languages seem to "argue" here. *Obviously* the JS way is wrong.
      path = path:sub(1, 1) == '/' and path or vim.fs.joinpath(root, path)
      return vim.fs.normalize(path)
    end)
    :totable()
end

return lean
