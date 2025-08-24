vim.o.display = 'lastline' -- Avoid neovim/neovim#11362
vim.o.directory = ''
vim.o.shada = ''

-- Apply compatibility fixes for path functions
local function dirname(path)
  return vim.fs and vim.fs.dirname and vim.fs.dirname(path) or vim.fn.fnamemodify(path, ':h')
end

local function joinpath(...)
  if vim.fs and vim.fs.joinpath then
    return vim.fs.joinpath(...)
  else
    local parts = {...}
    return table.concat(parts, '/')
  end
end

local this_dir = dirname(debug.getinfo(1, 'S').source:sub(2))
local lean_nvim_dir = dirname(this_dir)
local packpath = joinpath(lean_nvim_dir, 'packpath/*')
vim.opt.runtimepath:append(packpath)

-- Add lean.nvim to the runtime path early so we can load compatibility fixes
vim.opt.runtimepath:append(lean_nvim_dir)

-- Apply Neovim compatibility fixes early, before any LSP or plugin loading
pcall(function()
  require('lean.neovim_compat').apply_fixes()
end)

-- Doing this unconditionally seems to fail a random indent test?!?!
-- Inanis/Plenary will automatically set rtp+. (which seems wrong, but OK)
-- so really we need this just for `just nvim`...
if #vim.api.nvim_list_uis() ~= 0 then
  vim.opt.runtimepath:append(lean_nvim_dir)
end

local inspect = vim.env.LEAN_NVIM_LOG_INSPECT and vim.inspect
  or function(data)
    return vim.inspect(data, { newline = ' ', indent = '' })
  end

---@type lean.Config
vim.g.lean_config = {
  log = function(level, data)
    if level < vim.log.levels[vim.env.LEAN_NVIM_MIN_LOG_LEVEL or 'INFO'] then
      return
    end
    print(inspect(data), level)
  end,
  mappings = true,
}

vim.cmd [[
  runtime! plugin/lspconfig.vim
  runtime! plugin/matchit.vim
  runtime! plugin/plenary.vim
  runtime! plugin/switch.vim
  runtime! plugin/tcomment.vim
]]

-- plenary forks subprocesses, so enable coverage here when appropriate
if vim.env.LEAN_NVIM_COVERAGE then
  local luapath = joinpath(lean_nvim_dir, 'luapath')
  package.path = package.path
    .. ';'
    .. luapath
    .. '/share/lua/5.1/?.lua;'
    .. luapath
    .. '/share/lua/5.1/?/init.lua;;'
  package.cpath = package.cpath .. ';' .. luapath .. '/lib/lua/5.1/?.so;'
  require 'luacov'
end

if vim.env.LEAN_NVIM_DEBUG then
  local port = 8088
  if vim.env.LEAN_NVIM_DEBUG ~= '' and vim.env.LEAN_NVIM_DEBUG ~= '1' then
    port = tonumber(vim.env.LEAN_NVIM_DEBUG)
  end
  require('osv').launch { host = '127.0.0.1', port = port }
  vim.wait(5000)
end
