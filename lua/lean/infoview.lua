local lean3 = require('lean.lean3')

local M = {_infoview = nil}

local _INFOVIEW_BUF_NAME = 'lean://infoview'
local _DEFAULT_BUF_OPTIONS = {
  bufhidden = 'wipe',
  filetype = 'lean',
}
local _DEFAULT_WIN_OPTIONS = {
  cursorline = false,
  number = false,
  relativenumber = false,
  spell = false,
  wrap = true,
}

function M.update(infoview_bufnr)
  local _update = vim.b.lean3 and lean3.update_infoview or function(set_lines)
    local params = vim.lsp.util.make_position_params()
    -- Shift forward by 1, since in vim it's easier to reach word
    -- boundaries in normal mode.
    params.position.character = params.position.character + 1
    vim.lsp.buf_request(0, "$/lean/plainGoal", params, function(_, _, result)
      if not (result and result.goals) then
        return
      end
      local lines = {}
      for _, each in pairs(result.goals) do
        vim.list_extend(lines, vim.split(each, '\n', true))
      end
      set_lines(lines)
    end)
  end

  return _update(function(lines)
    vim.api.nvim_buf_set_option(infoview_bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_lines(infoview_bufnr, 0, -1, true, lines)
    vim.api.nvim_buf_set_option(infoview_bufnr, 'modifiable', false)
  end)
end

function M.enable(_)
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

  vim.api.nvim_exec(string.format([[
    augroup LeanInfoViewUpdate
      autocmd!
      autocmd CursorHold *.lean lua require'lean.infoview'.update(%d)
      autocmd CursorHoldI *.lean lua require'lean.infoview'.update(%d)
    augroup END
  ]], bufnr, bufnr), false)

  local current_window = vim.api.nvim_get_current_win()

  vim.cmd "vsplit"
  vim.cmd(string.format("buffer %d", bufnr))

  -- We're cheating by calling this a Lean file, but tree-sitter won't
  -- know how to deal with our cheating until we teach it, so turn it
  -- off even for Lean 4.
  pcall(vim.cmd, 'TSBufDisable highlight')

  local winnr = vim.api.nvim_get_current_win()

  for name, value in pairs(_DEFAULT_WIN_OPTIONS) do
    vim.api.nvim_win_set_option(winnr, name, value)
  end
  vim.api.nvim_set_current_win(current_window)

  M._infoview = { bufnr = bufnr, winnr = winnr }
  return bufnr
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

  vim.api.nvim_win_close(infoview.winnr, false)
  vim.api.nvim_buf_delete(infoview.bufnr, {})
end

function M.toggle()
  if M.is_open() then M.close() else M.open() end
end

return M
