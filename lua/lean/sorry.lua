local sorry = {}

function sorry.fill()
  local params = vim.lsp.util.make_position_params()
  local responses = vim.lsp.buf_request_sync(0, 'textDocument/hover', params)

  for _, response in pairs(responses) do
    local goals = response.result.contents[1].value:match("(%d+) goal")
    if goals then
      vim.cmd("normal " .. goals .. "o{ sorry },")
      return
    end
  end
end

return sorry
