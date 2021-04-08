local M = {}

function M.init()
  pcall(vim.cmd, 'TSBufDisable highlight')
  vim.b.lean3 = true
end

function M.update_infoview(set_lines)
  local params = vim.lsp.util.make_position_params()
  vim.lsp.buf_request(0, "textDocument/hover", params, function(_, _, result)
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
