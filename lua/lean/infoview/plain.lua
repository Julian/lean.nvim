---@brief [[
--- Support for "plain" goals (non-interactive / widget-less rendering).
---@brief ]]

---@tag lean.infoview.plain

local range_to_string = require('std.lsp').range_to_string

local Element = require('lean.tui').Element
local lsp = require 'lean.lsp'

local plain = {}

---Format a heading.
local function H(contents)
  return ('▼ %s'):format(contents)
end

---`$/lean/plainGoal` client<-server reply.
---@class PlainGoal
---@field rendered string The goals as pretty-printed Markdown, or something like "no goals" if accomplished.
---@field goals string[] The pretty-printed goals, empty if all accomplished.

---Render the current plain (tactic) goal state.
---@param params lsp.TextDocumentPositionParams
---@return string[]? goals the current plain goals
---@return Element[]? children the rendered goals
---@return lsp.ResponseError? err
function plain.goal(params)
  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return nil, nil, 'buffer not loaded'
  end

  local client = lsp.client_for(bufnr)
  if not client then
    return nil, nil, 'LSP server not connected'
  end

  params = vim.deepcopy(params)
  -- Shift forward by 1, since in vim it's easier to reach word
  -- boundaries in normal mode.
  params.position.character = params.position.character + 1
  local response = client.request_sync('$/lean/plainGoal', params, 1000, bufnr)
  local err = not response and 'no response' or response.err
  if err then
    return nil, nil, err
  end

  local goals = response.result and response.result.goals
  if not goals then
    return nil, {}
  end

  local children = vim.iter(goals):fold({}, function(acc, k)
    local sep = #acc == 0 and '' or '\n\n'
    table.insert(acc, Element:new { text = sep .. k })
    return acc
  end)

  return goals, children
end

---`$/lean/plainTermGoal` client<-server reply.
---@class PlainTermGoal
---@field goal string
---@field range lsp.Range

---Render the current plain (term) goal state.
---@param params lsp.TextDocumentPositionParams
---@return Element[]? term_goal the rendered goals
---@return LspError? err
function plain.term_goal(params)
  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return nil, 'buffer not loaded'
  end

  local client = lsp.client_for(bufnr)
  if not client then
    return nil, 'LSP server not connected'
  end

  local response = client.request_sync('$/lean/plainTermGoal', params, 1000, bufnr)
  local err = not response and 'no response' or response.err
  if err then
    return nil, err
  end

  local term_goal = response.result

  return term_goal
    and {
      Element:new {
        text = H(
          ('expected type (%s)\n'):format(range_to_string(term_goal.range)) .. term_goal.goal
        ),
      },
    }
end

return plain
