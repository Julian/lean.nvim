local components = require('lean.infoview.components')
local lean3 = { lsp = {} }

-- Split a Lean 3 server response on goals.
--
-- Looks for ⊢, but ignores indented following lines for multi-line
-- goals.
--
-- Really this should also make sure ⊢ is on the
-- start of the line via \_^, but this returns nil:
-- `vim.regex('\\_^b'):match_str("foo\nbar\nbaz\n")` and I don't
-- understand why; perhaps it's a neovim bug. Lua's string.gmatch also
-- seems not powerful enough to do this.
--
-- Important properties of the number 2:
--
--    * the only even prime number
--    * the number of problems you have after using regex to solve a problem
local _GOAL_MARKER = vim.regex('⊢ .\\{-}\n\\(\\s\\+.\\{-}\\(\n\\|$\\)\\)*\\zs')

--- Force a buffer to be treated as Lean 3.
function lean3.init()
  pcall(vim.cmd, 'TSBufDisable highlight')  -- tree-sitter-lean is lean4-only
  vim.b.lean3 = true
end

--- Enable the Lean 3 LSP.
--- Generally called by enabling the `lsp3` section in the configuration passed
--- to `lean.setup`.
---@param opts table: configuration options for the `lean3ls` language server
---@field extra_argv table: additional command line options to pass to `lean-language-server`
function lean3.lsp.enable(opts)
  require('lspconfig.lean3ls')
  opts.cmd = opts.cmd or vim.deepcopy(
    require('lspconfig/configs').lean3ls.document_config.default_config.cmd
  )
  local extra_argv = opts.extra_argv or { "-M", "4096" }
  table.insert(opts.cmd, '--')
  vim.list_extend(opts.cmd, extra_argv)
  opts.extra_argv = nil

  require('lspconfig').lean3ls.setup(opts)
end

--- Convert a Lean 3 response to one that the Lean 4 server would respond with.
local function upconvert_lsp_goal_to_lean4(response)
  local goals = {}
  for _, contents in ipairs(response.contents) do
    if contents.language == 'lean' and contents.value ~= 'no goals' then
      -- strip 'N goals' from the front (which is present for multiple goals)
      local rest_of_goals = contents.value:gsub('^%d+ goals?\n', '')

      repeat
        local end_of_goal = _GOAL_MARKER:match_str(rest_of_goals)
        table.insert(goals, vim.trim(rest_of_goals:sub(1, end_of_goal)))
        if not end_of_goal then break end
        rest_of_goals = rest_of_goals:sub(end_of_goal + 1)
      until rest_of_goals == ""
    end
  end
  return { goals = goals }
end

function lean3.update_infoview(set_lines)
  local params = vim.lsp.util.make_position_params()
  return vim.lsp.buf_request(0, "textDocument/hover", params, function(_, _, result)
    local lines = {}
    if result and type(result) == "table" and not vim.tbl_isempty(result.contents) then
      vim.list_extend(
        lines,
        components.goal(upconvert_lsp_goal_to_lean4(result)))
    end
    vim.list_extend(lines, components.diagnostics())

    set_lines(lines)
  end)
end

return lean3
