local lean3 = require('lean.lean3')
local leanlsp = require('lean.lsp')
local set_augroup = require('lean._nvimapi').set_augroup

local M = {_infoviews = {[0] = nil}, _opts = {}}

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
  winfixwidth = true,
  wrap = true,
}

local _SEVERITY = {
  [0] = "other",
  [1] = "error",
  [2] = "warning",
  [3] = "information",
  [4] = "hint",
}

-- Get the ID of the infoview corresponding to the current window.
local function get_idx()
  return 0
end

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
    return leanlsp.plain_goal(0, function(_, _, goal)
      leanlsp.plain_term_goal(0, function(_, _, term_goal)
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
  opts.width = opts.width or 50
  M._opts = opts
  set_augroup("LeanInfoview", [[
    autocmd BufWinEnter *.lean lua require'lean.infoview'.ensure_open()
  ]])
end

function M.is_open() return M._infoviews[get_idx()] ~= nil end

function M.ensure_open()
  local infoview_idx = get_idx()

  if M.is_open() then return M._infoviews[infoview_idx] end

  local infoview_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(infoview_bufnr, _INFOVIEW_BUF_NAME)
  for name, value in pairs(_DEFAULT_BUF_OPTIONS) do
    vim.api.nvim_buf_set_option(infoview_bufnr, name, value)
  end

  local current_window = vim.api.nvim_get_current_win()

  vim.cmd("botright " .. M._opts.width .. "vsplit")
  vim.cmd(string.format("buffer %d", infoview_bufnr))

  local window = vim.api.nvim_get_current_win()

  for name, value in pairs(_DEFAULT_WIN_OPTIONS) do
    vim.api.nvim_win_set_option(window, name, value)
  end
  -- Make sure we teardown even if someone manually :q's the infoview window.
  set_augroup("LeanInfoviewClose", string.format([[
    autocmd WinClosed <buffer> lua require'lean.infoview'._teardown(%d)
  ]], infoview_idx))
  vim.api.nvim_set_current_win(current_window)

  set_augroup("LeanInfoviewUpdate", string.format([[
    autocmd CursorHold *.lean lua require'lean.infoview'.update(%d)
    autocmd CursorHoldI *.lean lua require'lean.infoview'.update(%d)
  ]], infoview_bufnr, infoview_bufnr))

  M._infoviews[infoview_idx] = { bufnr = infoview_bufnr, window = window }

  return M._infoviews[infoview_idx]
end

M.open = M.ensure_open

-- Close all open infoviews (across all tabs).
function M.close_all()
  for _, _ in pairs(M._infoviews) do
    M.close()
  end
end

-- Close the infoview associated with the current window.
function M.close()
  if not M.is_open() then return end
  local infoview = M._teardown(get_idx())
  vim.api.nvim_win_close(infoview.window, true)
end

-- Teardown internal state for an infoview window.
function M._teardown(infoview_idx)
  local infoview = M._infoviews[infoview_idx]
  M._infoviews[infoview_idx] = nil

  set_augroup("LeanInfoview", "")
  set_augroup("LeanInfoviewUpdate", "")

  return infoview
end

function M.toggle()
  if M.is_open() then M.close() else M.open() end
end

return M
