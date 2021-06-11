local root_pattern = require('lspconfig.util').root_pattern

local M = {}

local find_project_root = root_pattern('leanpkg.toml')

-- Ideally this obviously would use a TOML parser but yeah choosing to
-- do nasty things and not add the dependency for now.
local _MARKER = '.*lean_version.*\".*:3.*'

-- If a TOML file with a lean3 version string is found, use filetype "lean3".
-- Otherwise use "lean" (lean4).
function M.detect()
  local project_root = find_project_root(vim.api.nvim_buf_get_name(0))
  if not project_root then vim.bo.ft = "lean" return end
  local _, result = pcall(vim.fn.readfile, project_root .. '/leanpkg.toml')
  for _, line in ipairs(result) do
    if line:match(_MARKER) then vim.bo.ft = "lean3" return end
  end
  vim.bo.ft = "lean"
end

return M
