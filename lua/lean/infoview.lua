local lean3 = require('lean.lean3')

local M = {_infoviews = {}, _infoviews_open = {}, _opts = {}}

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

local function get_idx()
  local src_win
  if M._opts.one_per_tab then
    src_win = vim.api.nvim_get_current_tabpage()
  else
    src_win = vim.api.nvim_get_current_win()
  end
  return src_win
end

local function refresh_infos()
  for key, _ in pairs(M._infoviews) do
    local window = M._infoviews[key].win
    local max_width = M._opts.max_width or 79
    if vim.api.nvim_win_get_width(window) > max_width then
      vim.api.nvim_win_set_width(window, max_width)
    end
  end
end

function M.update(src_winnr)
  -- grace period for server startup (prevents initial handler error for lean3 files)
  local succeeded, _ = vim.wait(5000, vim.lsp.buf.server_ready)
  if not succeeded then return end

  if M._infoviews_open[src_winnr] == false then
      return
  end

  local infoview_bufnr
  local infoview = M._infoviews[src_winnr]
  if not infoview then
    M._infoviews[src_winnr] = {}

    infoview_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(infoview_bufnr, _INFOVIEW_BUF_NAME .. infoview_bufnr)
    for name, value in pairs(_DEFAULT_BUF_OPTIONS) do
      vim.api.nvim_buf_set_option(infoview_bufnr, name, value)
    end

    local current_window = vim.api.nvim_get_current_win()

    if M._opts.one_per_tab then
      vim.cmd "botright vsplit"
    else
      vim.cmd "rightbelow vsplit"
    end
    vim.cmd(string.format("buffer %d", infoview_bufnr))

    local window = vim.api.nvim_get_current_win()

    for name, value in pairs(_DEFAULT_WIN_OPTIONS) do
      vim.api.nvim_win_set_option(window, name, value)
    end
    vim.api.nvim_set_current_win(current_window)

    local max_width = M._opts.max_width or 79
    if vim.api.nvim_win_get_width(window) > max_width then
      vim.api.nvim_win_set_width(window, max_width)
    end

    M._infoviews[src_winnr].buf = infoview_bufnr
    M._infoviews[src_winnr].win = window

  else
    infoview_bufnr = infoview.buf
  end

  local _update = vim.bo.ft == "lean" and lean3.update_infoview or function(set_lines)
    local current_buffer = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local params = vim.lsp.util.make_position_params()
    -- Shift forward by 1, since in vim it's easier to reach word
    -- boundaries in normal mode.
    params.position.character = params.position.character + 1
    return vim.lsp.buf_request(0, "$/lean/plainGoal", params, function(_, _, result)
      local lines = {}

      if type(result) == "table" and result.goals then
        vim.list_extend(lines,
          {#result.goals == 0 and '▶ goals accomplished 🎉' or
            #result.goals == 1 and '▶ 1 goal' or
            string.format('▶ %d goals', #result.goals)})
        for _, each in pairs(result.goals) do
          vim.list_extend(lines, {''})
          vim.list_extend(lines, vim.split(each, '\n', true))
        end
      end

      for _, diag in pairs(vim.lsp.diagnostic.get_line_diagnostics(current_buffer, cursor[0])) do
        local start = diag.range["start"]
        local end_ = diag.range["end"]
        vim.list_extend(lines, {'', string.format('▶ %d:%d-%d:%d: %s:',
          start.line+1, start.character+1, end_.line+1, end_.character+1, _SEVERITY[diag.severity])})
        vim.list_extend(lines, vim.split(diag.message, '\n', true))
      end

      set_lines(lines)
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
  if M._opts.one_per_tab == nil then M._opts.one_per_tab = true end
  M.set_update()
end

function M.set_update()
  local idx_call
  if M._opts.one_per_tab then
    idx_call = "vim.api.nvim_get_current_tabpage()"
  else
    idx_call = "vim.api.nvim_get_current_win()"
  end
  -- TODO: update autocommand to use filetypes rather than extension
  vim.api.nvim_exec(string.format([[
    augroup LeanInfoViewUpdate
      autocmd!
      autocmd CursorHold *.lean lua require'lean.infoview'.update(%s)
      autocmd CursorHoldI *.lean lua require'lean.infoview'.update(%s)
    augroup END
  ]], idx_call, idx_call), false)
end

function M.is_open()
  return M._infoviews_open[get_idx()] ~= false
end

function M.open()
  M._infoviews_open[get_idx()] = true
  return M._infoviews
end

function M.set_pertab()
  if M._opts.one_per_tab then return end

  M.close_all()

  M._opts.one_per_tab = true

  M.set_update()
end

function M.set_perwindow()
  if not M._opts.one_per_tab then return end

  M.close_all()

  M._opts.one_per_tab = false

  M.set_update()
end

function M.close_all()
  -- close all current infoviews
  for key, _ in pairs(M._infoviews) do
    M.close_win(key)
  end
  for key, _ in pairs(M._infoviews_open) do
    M._infoviews_open[key] = nil
  end
end

function M.close_win(src_winnr)
  if M._infoviews[src_winnr] then
    vim.api.nvim_win_close(M._infoviews[src_winnr].win, true)
  end

  -- NOTE: it seems this isn't necessary since unlisted buffers are deleted automatically?
  --if M._infoviews[src_win].buf then
  --  vim.api.nvim_buf_delete(M._infoviews[src_win].buf, { force = true })
  --end

  M._infoviews_open[src_winnr] = false
  M._infoviews[src_winnr] = nil
  -- necessary because closing a window can cause others to resize
  refresh_infos()
end

function M.close()
  if not M.is_open() then return end

  M.close_win(get_idx())
end

function M.toggle()
  if M.is_open() then M.close() else M.open() end
end

return M
