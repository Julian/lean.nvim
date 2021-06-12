local M = { handlers = {} }
local util = require('lspconfig.util')

function M.enable(opts)
  opts.commands = vim.tbl_extend("keep", opts.commands or {}, {
    LeanPlainGoal = {
      M.plain_goal;
      description = "Describe the current tactic state."
    };
    LeanPlainTermGoal = {
      M.plain_term_goal;
      description = "Describe the expected type of the current term."
    };
  })
  opts.handlers = vim.tbl_extend("keep", opts.handlers or {}, {
    ["$/lean/plainGoal"] = M.handlers.plain_goal_handler;
    ["$/lean/plainTermGoal"] = M.handlers.plain_term_goal_handler;
  })

  -- TODO: delete both of these once neovim/nvim-lspconfig#958 is merged
  opts.root_dir = function(fname)
      return util.root_pattern('leanpkg.toml')(fname) or util.find_git_ancestor(fname) or util.path.dirname(fname)
    end
  opts.on_new_config = function(config, root)
      if not util.path.is_file(root .. "/leanpkg.toml") then return end
      if not config.cmd_cwd then
        config.cmd_cwd = root
      end
    end;

  require('lspconfig').leanls.setup(opts)
end

-- Fetch goal state information from the server.
function M.plain_goal(bufnr, handler)
  -- Shift forward by 1, since in vim it's easier to reach word
  -- boundaries in normal mode.
  local params = vim.lsp.util.make_position_params()
  params.position.character = params.position.character + 1
  return vim.lsp.buf_request(bufnr, "$/lean/plainGoal", params, handler)
end

-- Fetch term goal state information from the server.
function M.plain_term_goal(bufnr, handler)
  local params = vim.lsp.util.make_position_params()
  return vim.lsp.buf_request(bufnr, "$/lean/plainTermGoal", params, handler)
end

function M.handlers.plain_goal_handler (_, method, result, _, _, config)
  config = config or {}
  config.focus_id = method
  if not (result and result.rendered) then
    return
  end
  local markdown_lines = vim.lsp.util.convert_input_to_markdown_lines(result.rendered)
  markdown_lines = vim.lsp.util.trim_empty_lines(markdown_lines)
  if vim.tbl_isempty(markdown_lines) then
    return
  end
  return vim.lsp.util.open_floating_preview(markdown_lines, "markdown", config)
end

function M.handlers.plain_term_goal_handler (_, method, result, _, _, config)
  config = config or {}
  config.focus_id = method
  if not (result and result.goal) then
    return
  end
  return vim.lsp.util.open_floating_preview(
    vim.split(result.goal, '\n'), "leaninfo", config
  )
end

return M
