---@brief [[
--- lean.nvim is a plugin providing Neovim support for the Lean interactive
--- theorem prover, developed by Leonardo de Moura and the Lean FRO.
---
--- To find out more, see https://github.com/Julian/lean.nvim.
---@brief ]]

local subprocess_check_output = require('lean._util').subprocess_check_output

---@tag lean.nvim

local lean = {
  mappings = {
    n = {
      ['<LocalLeader>i'] = '<Cmd>LeanInfoviewToggle<CR>',
      ['<LocalLeader>p'] = '<Cmd>LeanInfoviewPinTogglePause<CR>',
      ['<LocalLeader>x'] = '<Cmd>LeanInfoviewAddPin<CR>',
      ['<LocalLeader>c'] = '<Cmd>LeanInfoviewClearPins<CR>',
      ['<LocalLeader>dx'] = '<Cmd>LeanInfoviewSetDiffPin<CR>',
      ['<LocalLeader>dc'] = '<Cmd>LeanInfoviewClearDiffPin<CR>',
      ['<LocalLeader>dd'] = '<Cmd>LeanInfoviewToggleAutoDiffPin<CR>',
      ['<LocalLeader>dt'] = '<Cmd>LeanInfoviewToggleNoClearAutoDiffPin<CR>',
      ['<LocalLeader>w'] = '<Cmd>LeanInfoviewEnableWidgets<CR>',
      ['<LocalLeader>W'] = '<Cmd>LeanInfoviewDisableWidgets<CR>',
      ['<LocalLeader><Tab>'] = '<Cmd>LeanGotoInfoview<CR>',
      ['<LocalLeader>\\'] = '<Cmd>LeanAbbreviationsReverseLookup<CR>',
    },
    i = {},
  },
}

vim.filetype.add { extension = { lean = 'lean' } }

--- Setup function to be run in your init.lua (or init.vim).
---@param opts table: Configuration options
function lean.setup(opts)
  opts = opts or {}

  opts.abbreviations = opts.abbreviations or {}
  if opts.abbreviations.enable ~= false then
    require('lean.abbreviations').enable('*.lean', opts.abbreviations)
  end

  opts.infoview = opts.infoview or {}
  require('lean.infoview').enable(opts.infoview)
  require('lean.commands').enable()

  opts.lsp = opts.lsp or {}
  if opts.lsp.enable ~= false then
    require('lean.lsp').enable(opts.lsp)
  end

  local has_satellite, satellite = pcall(require, 'satellite.handlers')
  if has_satellite then
    satellite.register(require 'lean.satellite')
  end

  opts.progress_bars = opts.progress_bars or {}
  -- FIXME: Maybe someone eventually cares about enabling both.
  if not has_satellite and opts.progress_bars.enable ~= false then
    require('lean.progress_bars').enable(opts.progress_bars)
  end

  require('lean.ft').enable(opts.ft or {})

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

    command! LeanInfoviewToggle :lua require'lean.infoview'.toggle()
    command! LeanInfoviewPinTogglePause :lua require'lean.infoview'.pin_toggle_pause()
    command! LeanInfoviewAddPin :lua require'lean.infoview'.add_pin()
    command! LeanInfoviewClearPins :lua require'lean.infoview'.clear_pins()
    command! LeanInfoviewSetDiffPin :lua require'lean.infoview'.set_diff_pin()
    command! LeanInfoviewClearDiffPin :lua require'lean.infoview'.clear_diff_pin()
    command! LeanInfoviewToggleAutoDiffPin :lua require'lean.infoview'.toggle_auto_diff_pin(true)
    command! LeanInfoviewToggleNoClearAutoDiffPin :lua require'lean.infoview'.toggle_auto_diff_pin(false)
    command! LeanInfoviewEnableWidgets :lua require'lean.infoview'.enable_widgets()
    command! LeanInfoviewDisableWidgets :lua require'lean.infoview'.disable_widgets()
    command! LeanGotoInfoview :lua require'lean.infoview'.go_to()

    command! LeanAbbreviationsReverseLookup :lua require'lean.abbreviations'.show_reverse_lookup()

    command! LeanSorryFill :lua require'lean.sorry'.fill()
  ]]

  if opts.mappings == true then
    vim.cmd [[
      augroup lean_nvim_mappings
        autocmd!
        autocmd FileType lean lua require'lean'.use_suggested_mappings(true)
      augroup END
    ]]
  end

  -- needed for testing
  lean.config = opts
end

---Enable mappings for a given buffer
---@param bufnr? number the bufnr to enable mappings in, defaulting to 0
function lean.use_suggested_mappings(bufnr)
  local opts = { noremap = true, buffer = bufnr or 0 }
  for mode, mode_mappings in pairs(lean.mappings) do
    for lhs, rhs in pairs(mode_mappings) do
      vim.keymap.set(mode, lhs, rhs, opts)
    end
  end
end

--- Return the current Lean search path.
---
--- Includes both the Lean core libraries as well as project-specific
--- directories.
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
