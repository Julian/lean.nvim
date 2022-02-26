local tbl_repeat = require('lean._util').tbl_repeat

local sorry = {}

local function calculate_indent(line)
  -- This manual calculation ugliness hopefully will get helped by tree-sitter.
  local indent = vim.fn.indent(line)
  if indent == 0 then
    indent = vim.fn.indent(vim.fn.prevnonblank(line))
  end
  -- This also doesn't really respect 'expandtab...
  return string.rep(' ', indent)
end

--- Fill the current cursor position with `sorry`s to discharge all goals.
---
--- I.e., given 3 current goals, with 2 in front of the cursor, will insert:
---      { foo },<cursor>
---      { sorry },
---      { sorry },
function sorry.fill()
  local params = vim.lsp.util.make_position_params()
  local responses = vim.lsp.buf_request_sync(0, '$/lean/plainGoal', params)

  for _, response in pairs(responses) do
    if not response.result or not response.result.goals or vim.tbl_isempty(response.result.goals) then return end
    local goals = #response.result.goals
    if goals then
      local index = vim.api.nvim_win_get_cursor(0)[1]
      local indent = calculate_indent(index)
      local lines = tbl_repeat(indent .. "{ sorry },", goals)
      vim.api.nvim_buf_set_lines(0, index, index, true, lines)
      vim.api.nvim_win_set_cursor(0, { index + 1, #indent + 2 })  -- the 's'
      return
    end
  end
end

return sorry
