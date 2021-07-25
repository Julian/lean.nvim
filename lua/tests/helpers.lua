local assert = require('luassert')
local infoview = require('lean.infoview')

local lean = require('lean')

local api = vim.api
local helpers = {_clean_buffer_counter = 1}

-- everything disabled by default to encourage unit testing
local default_config = {
  treesitter = {
    enable = false
  },
  abbreviations = {
    builtin = false,
    compe = false,
    snippets = false,
  },
  mappings = false,
  infoview = {
    autoopen = false
  },
  lsp3 = {
    enable = false
  },
  lsp = {
    enable = false
  }
}

function helpers.setup(config)
  lean.setup(vim.tbl_deep_extend("keep", config, default_config))
end

--- Feed some keystrokes into the current buffer, replacing termcodes.
function helpers.feed(text, feed_opts)
  feed_opts = feed_opts or 'n'
  local to_feed = vim.api.nvim_replace_termcodes(text, true, false, true)
  api.nvim_feedkeys(to_feed, feed_opts, true)
end

--- Insert some text into the current buffer.
function helpers.insert(text, feed_opts)
  feed_opts = feed_opts or 'x'
  helpers.feed('i' .. text, feed_opts)
end

-- Even though we can delete a buffer, so should be able to reuse names,
-- we do this to ensure if a test fails, future ones still get new "files".
local function set_unique_name_so_we_always_have_a_separate_fake_file(bufnr)
  local counter = helpers._clean_buffer_counter
  helpers._clean_buffer_counter = helpers._clean_buffer_counter + 1
  local unique_name = string.format('unittest-%d.lean', counter)
  api.nvim_buf_set_name(bufnr, unique_name)
end

function helpers.wait_for_ready_lsp()
  local succeeded, _ = vim.wait(20000, vim.lsp.buf.server_ready)
  assert.message("LSP server was never ready.").True(succeeded)
end

--- Create a clean Lean buffer of the given filetype with the given contents.
--
--  Waits for the LSP to be ready before proceeding with a given callback.
--
--  Yes c(lean) may be a double entendre, and no I don't feel bad.
function helpers.clean_buffer(ft, contents, callback)
  return function()
    local bufnr = vim.api.nvim_create_buf(false, false)
    set_unique_name_so_we_always_have_a_separate_fake_file(bufnr)
    -- apparently necessary to trigger BufWinEnter
    vim.api.nvim_set_current_buf(bufnr)
    vim.opt_local.bufhidden = "hide"
    vim.opt_local.swapfile = false
    vim.opt.filetype = ft

    api.nvim_buf_call(bufnr, function()
      if not vim.tbl_isempty(vim.lsp.buf_get_clients()) then
        helpers.wait_for_ready_lsp()
      end

      api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(contents, '\n'))
      callback{
        source_file = { bufnr = bufnr },
      }
    end)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

--- Wait a few seconds for line diagnostics, erroring if none arrive.
function helpers.wait_for_line_diagnostics()
  local succeeded, _ = vim.wait(5000, function()
    return not vim.tbl_isempty(vim.lsp.diagnostic.get_line_diagnostics())
  end)
  assert.message("Waited for line diagnostics but none came.").True(succeeded)
end

--- The number of current windows.
function helpers.get_num_wins() return #vim.api.nvim_list_wins() end

local last_num_wins

local function set_num_wins() last_num_wins = helpers.get_num_wins() end
set_num_wins()

--- Assert about the entire buffer contents.
local function has_buf_contents(_, arguments)
  local buf = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  assert.equal(arguments[1], buf)
  return true
end

assert:register('assertion', 'contents', has_buf_contents)

local function has_all(_, arguments)
  local text = arguments[1]
  local expected = arguments[2]
  for _, string in pairs(expected) do
    assert.has_match(string, text, nil, true)
  end
  return true
end

local prev_buf_max = -1
local prev_win_max = -1
local prev_buf
local prev_win

local function change_infoview(state, _)
  local this_infoview = infoview.get_current_infoview()
  local buf = this_infoview.bufnr
  local win = this_infoview.window
  local result =
    ((not buf and not this_infoview.is_open) or (buf and prev_buf ~= buf and this_infoview.is_open
      and vim.api.nvim_buf_is_valid(buf))) and
    ((not win and not this_infoview.is_open) or (win and prev_win ~= win and this_infoview.is_open
      and vim.api.nvim_win_is_valid(win))) and
    helpers.get_num_wins() == last_num_wins
  prev_buf = buf
  prev_win = win
  state.failure_message = table.concat({
    "Failed to change: ",
    ("prev_buf: %s, buf: %s, buf valid: %s"):format(vim.inspect(prev_buf), vim.inspect(buf),
      vim.inspect(buf and vim.api.nvim_buf_is_valid(buf))),
    ("prev_win: %s, win: %s, win valid: %s"):format(vim.inspect(prev_win), vim.inspect(win),
      vim.inspect(win and vim.api.nvim_win_is_valid(win))),
    "is_open: " .. vim.inspect(this_infoview.is_open),
    ("num_wins: %d, last_num_wins: %d"):format(helpers.get_num_wins(), last_num_wins)
  }, "\n")

  return result
end

local function open_infoview(state, arguments)
  local result
  local this_infoview = infoview.get_current_infoview()

  local maintain = arguments[1]

  local failure_message = {}

  local buf = this_infoview.bufnr
  local win = this_infoview.window
  if state.mod then
    vim.list_extend(failure_message,
    {
      "Failed to open: ",
      "maintain: " .. vim.inspect(maintain),
      ("prev_buf_max: %s, buf: %s, prev_buf: %s, buf valid: %s"):format(vim.inspect(prev_buf_max),
        vim.inspect(buf), vim.inspect(prev_buf),
        vim.inspect(buf and vim.api.nvim_buf_is_valid(buf))),
      ("prev_win_max: %s, win: %s, prev_win: %s, win valid: %s"):format(vim.inspect(prev_win_max),
        vim.inspect(win), vim.inspect(prev_win),
        vim.inspect(win and vim.api.nvim_win_is_valid(win))),
      "is_open: " .. vim.inspect(this_infoview.is_open),
      ("num_wins: %d, last_num_wins: %d"):format(helpers.get_num_wins(), last_num_wins)
    })
    if maintain then
      result = this_infoview.is_open and
        buf and prev_buf == buf and vim.api.nvim_buf_is_valid(buf) and
        win and prev_win == win and vim.api.nvim_win_is_valid(win) and
        helpers.get_num_wins() == last_num_wins
    else
      -- make sure this is a brand new buffer/window
      result = this_infoview.is_open and
        prev_buf_max < buf and vim.api.nvim_buf_is_valid(buf) and
        prev_win_max < win and vim.api.nvim_win_is_valid(win) and
        helpers.get_num_wins() == last_num_wins + 1
      prev_buf_max = buf
      prev_win_max = win
    end
  else
    vim.list_extend(failure_message,
    {
      "Failed to close: ",
      "maintain: " .. vim.inspect(maintain),
      ("buf: %s, prev_buf: %s, buf valid: %s"):format(vim.inspect(buf), vim.inspect(prev_buf),
        prev_buf and vim.inspect(vim.api.nvim_buf_is_valid(prev_buf))),
      ("win: %s, prev_win: %s, win valid: %s"):format(vim.inspect(win), vim.inspect(prev_win),
        prev_win and vim.inspect(vim.api.nvim_win_is_valid(prev_win))),
      "is_open: " .. vim.inspect(this_infoview.is_open),
      ("num_wins: %d, last_num_wins: %d"):format(helpers.get_num_wins(), last_num_wins)
    })
    if maintain then
      result = buf or win or prev_win or prev_buf or this_infoview.is_open
        or helpers.get_num_wins() ~= last_num_wins
    else
      local unopened = arguments[2]
      vim.list_extend(failure_message, {"unopened: " .. vim.inspect(unopened)})
      if unopened then
        -- if not previously opened, we don't care about prev_win or prev_buf being accurate
        result = buf or win or this_infoview.is_open
          or helpers.get_num_wins() ~= last_num_wins
      else
        -- make sure the previous window was closed
        result = this_infoview.is_open or buf or win or
          (not prev_buf) or vim.api.nvim_buf_is_valid(prev_buf) or
          (not prev_win) or vim.api.nvim_win_is_valid(prev_win) or
          helpers.get_num_wins() ~= last_num_wins - 1
      end
    end
  end
  prev_buf = buf
  prev_win = win
  state.failure_message = table.concat(failure_message, "\n")

  set_num_wins()

  return result
end

local function close_win()
  local result = helpers.get_num_wins() == last_num_wins - 1
  set_num_wins()
  return result
end

local function new_win()
  local result = helpers.get_num_wins() == last_num_wins + 1
  set_num_wins()
  return result
end

assert:register("assertion", "has_all", has_all)
assert:register("assertion", "open_infoview", open_infoview)
assert:register("assertion", "change_infoview", change_infoview)
assert:register("assertion", "close_win", close_win)
assert:register("assertion", "new_win", new_win)

return helpers
