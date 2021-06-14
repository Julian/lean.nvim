local M = {}

local lean3 = require("lean.lean3")

local find_project_root = require('lspconfig.util').root_pattern('leanpkg.toml')

-- Ideally this obviously would use a TOML parser but yeah choosing to
-- do nasty things and not add the dependency for now.
local _MARKER = '.*lean_version.*\".*:3.*'

function M.detect()
  local ft = "lean"
  local project_root = find_project_root(vim.api.nvim_buf_get_name(0))
  if project_root then
    local result = vim.fn.readfile(project_root .. '/leanpkg.toml')
    for _, line in ipairs(result) do
      if line:match(_MARKER) then ft = "lean3" end
    end
  end
  M.set(ft)
end

function M.set(ft)
  vim.api.nvim_command("setfiletype " .. ft)
  if vim.bo.ft == "lean3" then lean3.init() end
end

return M
