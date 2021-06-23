local lean3 = require('lean.lean3')
local leanlsp = require('lean.lsp')
local set_augroup = require('lean._nvimapi').set_augroup

local infoview = {_infoviews = {}, _opts = {}}

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
  return vim.api.nvim_win_get_tabpage(0)
end

function infoview.update()
  local infoview_bufnr = infoview.open().bufnr
  local _update = vim.b.lean3 and lean3.update_infoview or function(set_lines)
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

      for _, diag in pairs(vim.lsp.diagnostic.get_line_diagnostics()) do
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

function infoview.enable(opts)
  opts.width = opts.width or 50
  infoview._opts = opts
  set_augroup("LeanInfoview", [[
    autocmd BufWinEnter *.lean lua require'lean.infoview'.ensure_open()
  ]])
  infoview.set_autocmds()
end

function infoview.set_autocmds()
  vim.api.nvim_exec(string.format([[
    augroup LeanInfoviewInit
      autocmd!
      autocmd FileType lean3 lua require'lean.infoview'.buf_setup()
      autocmd FileType lean lua require'lean.infoview'.buf_setup()
    augroup END
  ]]), false)
end

function infoview.buf_setup()
  set_augroup("LeanInfoviewSetUpdate", [[
    autocmd WinEnter <buffer> lua require'lean.infoview'.set_update()
    autocmd BufEnter <buffer> lua require'lean.infoview'.set_update()
  ]], true)
end

function infoview.set_update()
  if not (vim.bo.ft == "lean" or vim.bo.ft == "lean3") then return end
  if infoview.is_open() then
    set_augroup("LeanInfoviewUpdate", [[
      autocmd CursorHold <buffer> lua require'lean.infoview'.update()
      autocmd CursorHoldI <buffer> lua require'lean.infoview'.update()
    ]], true)
  else
    set_augroup("LeanInfoviewUpdate", "", true)
  end
end

function infoview.is_open() return infoview._infoviews[get_idx()] ~= nil end

function infoview.ensure_open()
  local infoview_idx = get_idx()

  if infoview.is_open() then return infoview._infoviews[infoview_idx] end

  local infoview_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(infoview_bufnr, _INFOVIEW_BUF_NAME .. ":" .. infoview_idx)
  for name, value in pairs(_DEFAULT_BUF_OPTIONS) do
    vim.api.nvim_buf_set_option(infoview_bufnr, name, value)
  end

  local current_window = vim.api.nvim_get_current_win()

  vim.cmd("botright " .. infoview._opts.width .. "vsplit")
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

  infoview._infoviews[infoview_idx] = { bufnr = infoview_bufnr, window = window }

  infoview.set_update()
  return infoview._infoviews[infoview_idx]
end

infoview.open = infoview.ensure_open

-- Close all open infoviews (across all tabs).
function infoview.close_all()
  for _, _ in pairs(infoview._infoviews) do
    infoview.close()
  end
end

-- Close the infoview associated with the current window.
function infoview.close()
  if not infoview.is_open() then return end
  local current_infoview = infoview._teardown(get_idx())
  vim.api.nvim_win_close(current_infoview.window, true)
  infoview.set_update()
end

-- Teardown internal state for an infoview window.
function infoview._teardown(infoview_idx)
  local current_infoview = infoview._infoviews[infoview_idx]
  infoview._infoviews[infoview_idx] = nil

  set_augroup("LeanInfoview", "")

  return current_infoview
end

function infoview.toggle()
  if infoview.is_open() then infoview.close() else infoview.open() end
end

--- Retrieve the current combined contents of the infoview as a string.
function infoview.get_info_lines()
  if not infoview.is_open() then return end
  local infoview_info = infoview.open()
  return table.concat(vim.api.nvim_buf_get_lines(infoview_info.bufnr, 0, -1, true), "\n")
end

return infoview
