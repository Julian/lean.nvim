local M = {}

-- Ideally this obviously would use a TOML parser but yeah choosing to
-- do nasty things and not add the dependency for now.
local _MARKER = '.*lean_version.*\".*:3.*'

local find_project_root = require('lspconfig.util').root_pattern('leanpkg.toml')

function M.init()
  pcall(vim.cmd, 'TSBufDisable highlight')  -- tree-sitter-lean is lean4-only
  vim.b.lean3 = true
end

function M.is_lean3_project()
  local project_root = find_project_root(vim.api.nvim_buf_get_name(0))
  if not project_root then return false end
  local result = vim.fn.readfile(project_root .. '/leanpkg.toml')
  for _, line in ipairs(result) do
    if line:match(_MARKER) then return true end
  end
  return false
end

function M.update_infoview(set_lines)
  local params = vim.lsp.util.make_position_params()
  return vim.lsp.buf_request(0, "textDocument/hover", params, function(_, _, result)
    if not (type(result) == "table" and result.contents) then
      return
    end
    local lines = {}
    for _, contents in ipairs(result.contents) do
      if contents.language == 'lean' then
        vim.list_extend(lines, vim.split(contents.value, '\n', true))
      end
    end
    set_lines(lines)
  end)
end

return M
