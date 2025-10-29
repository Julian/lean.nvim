---@mod lean.sorry Client-side sorrying

---@brief [[
--- Support for sorrying multiple goals.
---
--- You should generally prefer to use code actions for this functionality, but this module
--- is maintained for a subset of users who prefer its behavior over the current code action
--- behavior.
---@brief ]]

local lsp = require 'lean.lsp'

local function calculate_indent(line)
  local indent = vim.fn.indent(line)

  if indent == 0 then
    indent = vim.fn.indent(vim.fn.prevnonblank(line))
  end

  if vim.bo.filetype == 'lean' then
    local line_text = vim.fn.getline(line):gsub('^%s*', '')
    if line_text:sub(1, 2) == '\194\183' then
      indent = indent + 2
    end
  end

  return string.rep(' ', indent)
end

return {
  ---Fill the current cursor position with `sorry`s to discharge all goals.
  fill = function()
    local client = lsp.client_for(0)
    local params = vim.lsp.util.make_position_params(0, 'utf-16')

    local response = client:request_sync('$/lean/plainGoal', params, 1000, 0)
    ---@type PlainGoal?
    local result = response and response.result
    if not result or not result.goals or vim.tbl_isempty(result.goals) then
      return
    end

    local goals = #result.goals
    local index = vim.api.nvim_win_get_cursor(0)[1]
    local indent = calculate_indent(index)

    local sorries, offset = { indent .. 'sorry' }, #indent
    if goals > 1 then
      local focus = '· '
      local focused_sorry = ('%s%ssorry'):format(indent, focus)
      sorries = {}
      for _ = 1, goals do
        table.insert(sorries, focused_sorry)
      end
      offset = offset + #focus
    end

    vim.api.nvim_buf_set_lines(0, index, index, true, sorries)
    vim.api.nvim_win_set_cursor(0, { index + 1, offset }) -- the 's'
  end,
}
