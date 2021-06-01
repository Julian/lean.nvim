local M = {}

function M.init()
  pcall(vim.cmd, 'TSBufDisable highlight')  -- tree-sitter-lean is lean4-only
end

function M.is_lean3_project()
    return vim.bo.ft == "lean"
end

function M.detect()
  if M.is_lean3_project() then M.init() end
end

function M.update_infoview(set_lines)
  local params = vim.lsp.util.make_position_params()
  return vim.lsp.buf_request(0, "textDocument/hover", params, function(_, _, result)
    if not (result and result.contents) then
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
