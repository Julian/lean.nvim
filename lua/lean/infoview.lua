local lean3 = require('lean.lean3')

local M = {_infoview = nil, _opts = {}}

local _INFOVIEW_BUF_NAME = 'lean://infoview'
local _DEFAULT_BUF_OPTIONS = {
  bufhidden = 'wipe',
  filetype = 'leaninfo',
  modifiable = false,
}
local _DEFAULT_WIN_OPTIONS = {
  cursorline = false,
  number = false,
  relativenumber = false,
  spell = false,
  wrap = true,
}

local _SEVERITY = {
  [0] = "other",
  [1] = "error",
  [2] = "warning",
  [3] = "information",
  [4] = "hint",
}

function M.update(infoview_bufnr)
  local _update = vim.b.lean3 and lean3.update_infoview or function(set_lines)
    local current_buffer = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local params = vim.lsp.util.make_position_params()
    -- Shift forward by 1, since in vim it's easier to reach word
    -- boundaries in normal mode.
    local goal_params = vim.deepcopy(params)
    goal_params.position.character = goal_params.position.character + 1
    local update = function(goal, term_goal)
      local lines = {}

      if type(goal) == "table" and goal.goals then
        vim.list_extend(lines,
          {#goal.goals == 0 and '▶ goals accomplished 🎉' or
            #goal.goals == 1 and '▶ 1 goal' or
            string.format('▶ %d goals', #goal.goals)})
        for _, each in pairs(goal.goals) do
          vim.list_extend(lines, {''})
          vim.list_extend(lines, vim.split(each, '\n', true))
        end
      end

      if type(term_goal) == "table" and term_goal.goal then
        local start = term_goal.range["start"]
        local end_ = term_goal.range["end"]
        vim.list_extend(lines, {'', string.format('▶ expected type (%d:%d-%d:%d)',
          start.line+1, start.character+1, end_.line+1, end_.character+1)})
        vim.list_extend(lines, vim.split(term_goal.goal, '\n', true))
      end

      for _, diag in pairs(vim.lsp.diagnostic.get_line_diagnostics(current_buffer, cursor[0])) do
        local start = diag.range["start"]
        local end_ = diag.range["end"]
        vim.list_extend(lines, {'', string.format('▶ %d:%d-%d:%d: %s:',
          start.line+1, start.character+1, end_.line+1, end_.character+1, _SEVERITY[diag.severity])})
        vim.list_extend(lines, vim.split(diag.message, '\n', true))
      end

      set_lines(lines)
    end
    return vim.lsp.buf_request(0, "$/lean/plainGoal", goal_params, function(_, _, goal)
      vim.lsp.buf_request(0, "$/lean/plainTermGoal", params, function(_, _, term_goal)
        update(goal, term_goal)
      end)
    end)
  end

  return _update(function(lines)
    vim.api.nvim_buf_set_option(infoview_bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_lines(infoview_bufnr, 0, -1, true, lines)
    -- HACK: This shouldn't really do anything, but I think there's a neovim
    --       display bug. See #27 and neovim/neovim#14663. Specifically,
    --       as of NVIM v0.5.0-dev+e0a01bdf7, without this, updating a long
    --       infoview with shorter contents doesn't properly redraw.
    vim.api.nvim_buf_call(infoview_bufnr, vim.fn.winline)
    vim.api.nvim_buf_set_option(infoview_bufnr, 'modifiable', false)
  end)
end

function M.enable(opts)
  M._opts = opts
  vim.api.nvim_exec([[
    augroup LeanInfoViewOpen
      autocmd!
      autocmd BufWinEnter *.lean lua require'lean.infoview'.ensure_open()
    augroup END
  ]], false)
end

function M.is_open() return M._infoview ~= nil end

function M.ensure_open()
  if M.is_open() then return M._infoview.bufnr end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, _INFOVIEW_BUF_NAME)
  for name, value in pairs(_DEFAULT_BUF_OPTIONS) do
    vim.api.nvim_buf_set_option(bufnr, name, value)
  end

  local current_window = vim.api.nvim_get_current_win()

  vim.cmd "botright vsplit"
  vim.cmd(string.format("buffer %d", bufnr))

  local window = vim.api.nvim_get_current_win()

  for name, value in pairs(_DEFAULT_WIN_OPTIONS) do
    vim.api.nvim_win_set_option(window, name, value)
  end
  vim.api.nvim_set_current_win(current_window)

  local max_width = M._opts.max_width or 79
  if vim.api.nvim_win_get_width(window) > max_width then
    vim.api.nvim_win_set_width(window, max_width)
  end

  vim.api.nvim_exec(string.format([[
    augroup LeanInfoViewUpdate
      autocmd!
      autocmd CursorHold *.lean lua require'lean.infoview'.update(%d)
      autocmd CursorHoldI *.lean lua require'lean.infoview'.update(%d)
    augroup END
  ]], bufnr, bufnr), false)

  M._infoview = { bufnr = bufnr, window = window }
  return M._infoview
end

M.open = M.ensure_open

function M.close()
  if not M.is_open() then return end

  local infoview = M._infoview
  M._infoview = nil

  vim.api.nvim_exec([[
    augroup LeanInfoViewOpen
      autocmd!
    augroup END

    augroup LeanInfoViewUpdate
      autocmd!
    augroup END
  ]], false)

  vim.api.nvim_win_close(infoview.window, true)
  vim.api.nvim_buf_delete(infoview.bufnr, { force = true })
end

function M.toggle()
  if M.is_open() then M.close() else M.open() end
end

return M
