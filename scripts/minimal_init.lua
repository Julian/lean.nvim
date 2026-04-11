vim.o.display = 'lastline' -- Avoid neovim/neovim#11362
vim.o.directory = ''
vim.o.shada = ''

local this_dir = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local lean_nvim_dir = vim.fs.dirname(this_dir)
local packpath = vim.fs.joinpath(lean_nvim_dir, 'packpath/*')
vim.opt.runtimepath:append(packpath)

-- Doing this unconditionally seems to fail a random indent test?!?!
-- Inanis will automatically set rtp+. (which seems wrong, but OK)
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
  debug = {
    log = function(level, data)
      if level < vim.log.levels[vim.env.LEAN_NVIM_MIN_LOG_LEVEL or 'INFO'] then
        return
      end
      print(inspect(data), level)
    end,
    rpc_history = 50,
  },
  stderr = {
    on_lines = function(lines)
      print('error: ' .. lines)
    end,
  },
  infoview = { update_cooldown = 0 },
  mappings = true,
}

vim.cmd [[
  runtime! plugin/matchit.vim
  runtime! plugin/switch.vim
  runtime! plugin/tcomment.vim
]]

-- The test runner forks subprocesses, so enable coverage here when appropriate
if vim.env.LEAN_NVIM_COVERAGE then
  local luapath = vim.fs.joinpath(lean_nvim_dir, 'luapath')
  package.path = package.path
    .. ';'
    .. luapath
    .. '/share/lua/5.1/?.lua;'
    .. luapath
    .. '/share/lua/5.1/?/init.lua;;'
  package.cpath = package.cpath .. ';' .. luapath .. '/lib/lua/5.1/?.so;'
  require 'luacov'
end

-- Force-kill LSP servers on exit so they don't linger as orphans.
-- Neovim's default VimLeavePre sends a graceful shutdown,
-- but Lean servers can take awhile to wind down.
-- Let's just be sure they don't stick around by force stopping.
vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    for _, client in ipairs(vim.lsp.get_clients()) do
      client:stop(true)
    end
  end,
})

if vim.env.LEAN_NVIM_DEBUG then
  local port = 8088
  if vim.env.LEAN_NVIM_DEBUG ~= '' and vim.env.LEAN_NVIM_DEBUG ~= '1' then
    port = tonumber(vim.env.LEAN_NVIM_DEBUG)
  end
  require('osv').launch { host = '127.0.0.1', port = port }
  vim.wait(5000)
end
