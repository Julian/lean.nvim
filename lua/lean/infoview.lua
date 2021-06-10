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

-- get infoview index (either window number or tabpage depending on per-win/per-tab mode)
local function get_idx()
  return M._opts.one_per_tab and vim.api.nvim_get_current_tabpage()
    or vim.api.nvim_get_current_win()
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

-- physically close infoview, then erase it
local function close_win(src_idx)
  if M._infoviews[src_idx] then
    vim.api.nvim_win_close(M._infoviews[src_idx].win, true)
  end

  M._infoviews_open[src_idx] = nil
  M._infoviews[src_idx] = nil

  -- necessary because closing a window can cause others to resize
  refresh_infos()
end

-- create autocmds under the specified group and local to
-- the given buffer; clears any existing autocmds
-- from the buffer beforehand
local function set_autocmds_guard(group, autocmds, bufnum)
  local buffer_string = bufnum == 0 and "<buffer>"
    or string.format("<buffer=%d>", bufnum)

  vim.api.nvim_exec(string.format([[
    augroup %s
      autocmd! %s * %s
      %s
    augroup END
  ]], group, group, buffer_string, autocmds), false)
end

function M.update()
  local src_idx = get_idx()

  if M._infoviews_open[src_idx] == false then
      return
  end

  local infoview_bufnr
  local infoview = M._infoviews[src_idx]
  if not infoview then
    M._infoviews[src_idx] = {}

    infoview_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(infoview_bufnr, _INFOVIEW_BUF_NAME .. infoview_bufnr)
    for name, value in pairs(_DEFAULT_BUF_OPTIONS) do
      vim.api.nvim_buf_set_option(infoview_bufnr, name, value)
    end

    local current_window = vim.api.nvim_get_current_win()
    local current_tab = vim.api.nvim_get_current_tabpage()

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
    -- This makes the infoview robust to manually being closed by the user
    -- (though they technically shouldn't do this).
    -- It makes sure that the infoview is erased from the table when this happens.
    set_autocmds_guard("LeanInfoViewWindow", string.format([[
      autocmd WinClosed <buffer> lua require'lean.infoview'.close_win_wrapper(%s, %s, false, true)
    ]], current_window, current_tab), 0)
    vim.api.nvim_set_current_win(current_window)

    M._infoviews[src_idx].buf = infoview_bufnr
    M._infoviews[src_idx].win = window

  else
    infoview_bufnr = infoview.buf
  end

  refresh_infos()

  local _update = vim.bo.ft == "lean3" and require('lean.lean3').update_infoview or function(set_lines)
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
  if opts.one_per_tab == nil then opts.one_per_tab = true end
  M._opts = opts
  M.set_autocmds()
end

-- TODO: once neovim implements autocmds in its lua api, we can make
-- the publicly exposed functions used below into local ones

function M.set_autocmds()
  vim.api.nvim_exec(string.format([[
    augroup LeanInfoView
      autocmd!
      autocmd FileType lean3 lua require'lean.infoview'.set_update_autocmds()
      autocmd FileType lean lua require'lean.infoview'.set_update_autocmds()
      autocmd FileType lean3 lua require'lean.infoview'.set_closed_autocmds()
      autocmd FileType lean lua require'lean.infoview'.set_closed_autocmds()
    augroup END
  ]]), false)
end

function M.set_update_autocmds()
  -- guarding is necessary here because I noticed the FileType event being
  -- triggered multiple times for a single file (not sure why)
  set_autocmds_guard("LeanInfoViewUpdate", [[
    autocmd CursorHold <buffer> lua require'lean.infoview'.update()
    autocmd CursorHoldI <buffer> lua require'lean.infoview'.update()
  ]], 0)
end

function M.set_closed_autocmds()
  set_autocmds_guard("LeanInfoViewClose", [[
    autocmd QuitPre <buffer> lua require'lean.infoview'.close_win_wrapper(-1, -1, true, false)
    autocmd WinClosed <buffer> ]] ..
    [[lua require'lean.infoview'.close_win_wrapper(tonumber(vim.fn.expand('<afile>')), -1, false, false)
  ]], 0)
end

function M.close_win_wrapper(src_winnr, src_tabnr, close_info, already_closed)
  if src_winnr == -1 then
    src_winnr = vim.api.nvim_get_current_win()
  end
  if src_tabnr == -1 then
    src_tabnr = vim.api.nvim_win_get_tabpage(src_winnr)
  end
  local src_idx = src_winnr
  if M._opts.one_per_tab then
    src_idx = src_tabnr

    if not already_closed then
      -- do not close infoview if there are remaining lean files
      -- in the tab
      for _, win in pairs(vim.api.nvim_tabpage_list_wins(src_idx)) do
        if win == src_winnr then goto continue end
        local buf = vim.api.nvim_win_get_buf(win)
        local ft =  vim.api.nvim_buf_get_option(buf, "filetype")
        if ft == "lean3" or ft == "lean" then return end
        ::continue::
      end
    end
  end

  if not already_closed then
    -- this check is needed since apparently WinClosed can be triggered
    -- multiple times for a single window close?
    if M._infoviews[src_idx] ~= nil then
      -- remove these autocmds so the infoview can now be closed manually without issue
      set_autocmds_guard("LeanInfoViewWindow", "", M._infoviews[src_idx].buf)
    end
  end

  close_win(src_idx)
end

function M.is_open()
  return M._infoviews_open[get_idx()] ~= false
end

function M.open()
  local src_idx = get_idx()
  M._infoviews_open[src_idx] = true
  return M._infoviews[src_idx]
end

function M.set_pertab()
  if M._opts.one_per_tab then return end

  M.close_all()

  M._opts.one_per_tab = true
end

function M.set_perwindow()
  if not M._opts.one_per_tab then return end

  M.close_all()

  M._opts.one_per_tab = false
end

function M.close_all()
  -- close all current infoviews
  for key, _ in pairs(M._infoviews) do
    close_win(key)
  end
  for key, _ in pairs(M._infoviews_open) do
    M._infoviews_open[key] = nil
  end
end

function M.close()
  if not M.is_open() then return end

  close_win(get_idx())
end

function M.toggle()
  if M.is_open() then M.close() else M.open() end
end

return M
