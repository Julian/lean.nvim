local util = require'lean.util'

-- Ideally this obviously would use a TOML parser but yeah choosing to
-- do nasty things and not add the dependency for now.
local _MARKER = '.*lean_version.*\".*:3.*'


local M = {}

-- If a TOML file with a lean3 version string is found, use filetype "lean3".
-- Otherwise use "lean" (lean4).
function M.detect()
  local toml_file = util.find_toml(vim.api.nvim_buf_get_name(0))
  if not toml_file then vim.bo.ft = "lean" return end
  local _, result = pcall(vim.fn.readfile, toml_file)
  for _, line in ipairs(result) do
    if line:match(_MARKER) then vim.bo.ft = "lean3" return end
  end
  vim.bo.ft = "lean"
end

return M
