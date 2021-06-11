local lspconfig = require('lspconfig')
local M = {lsp = {}}

function M.lsp.enable(opts)
  -- REMOVEME: We can do this unconditionally once neovim/nvim-lspconfig#958 is merged
  if lspconfig.lean3ls then lspconfig.lean3ls.setup(opts) end
end

function M.init()
  pcall(vim.cmd, 'TSBufDisable highlight')  -- tree-sitter-lean is lean4-only
end

function M.is_lean3_project()
  return vim.bo.ft == "lean3"
end

function M.detect()
  if M.is_lean3_project() then M.init() end
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
