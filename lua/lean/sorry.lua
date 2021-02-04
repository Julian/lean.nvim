local sorry = {}

--- Fill the current cursor position with `sorry`s to discharge all goals.
--
--  I.e., given 3 current goals, with 2 in front of the cursor will insert:
--       { foo },<cursor>
--       { sorry },
--       { sorry },
function sorry.fill()
  local params = vim.lsp.util.make_position_params()
  local responses = vim.lsp.buf_request_sync(0, 'textDocument/hover', params)

  for _, response in pairs(responses) do
    if vim.tbl_isempty(response.result.contents) then return end
    local goals = response.result.contents[1].value:match("(%d+) goal")
    if goals then
      vim.cmd("normal " .. goals .. "o{ sorry },")
      return
    end
  end
end

return sorry
