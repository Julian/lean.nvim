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

--- The number of current windows.
function helpers.get_num_wins() return #vim.api.nvim_list_wins() end

local last_wins = {}
local last_win = nil
local last_win_max = -1

local function get_wins()
  local wins = {}
  for _, win in pairs(vim.api.nvim_list_wins()) do
    wins[win] = true
  end

  return wins
end

local function update_wins(_, arguments)
  -- inductive hypothesis: last_wins is accurate to immediately before creating/closing any of the given windows
  local expected_wins = vim.deepcopy(last_wins)

  local opened_wins = arguments[1] or {}
  local closed_wins = arguments[2] or {}

  -- for ensuring no collisions
  local opened_win_set = {}

  for _, opened_win in pairs(opened_wins) do
    -- should be an actual window
    assert.is_truthy(vim.api.nvim_win_is_valid(opened_win))

    -- should be brand new
    assert.is_truthy(opened_win > last_win_max)
    assert.is_falsy(opened_win_set[opened_win])

    expected_wins[opened_win] = true
    opened_win_set[opened_win] = true
  end

  for _, closed_win in pairs(closed_wins) do
    -- should not be a window
    assert.is_falsy(vim.api.nvim_win_is_valid(closed_win))

    -- should have previously existed (should not pass a random previously/never closed window)
    assert.is_truthy(expected_wins[closed_win])

    expected_wins[closed_win] = nil
  end

  assert.message("expected: " .. vim.inspect(expected_wins) .. "\n got: " .. vim.inspect(get_wins())).is_truthy(
    vim.deep_equal(expected_wins, get_wins()))

  for _, opened_win in pairs(opened_wins) do
    if opened_win > last_win_max then last_win_max = opened_win end
  end

  -- maintain IH
  last_wins = get_wins()

  -- also maintain IH for closed_win
  last_win = vim.api.nvim_get_current_win()

  return true
end

local function created_win(_, arguments)
  local new_wins = arguments[1]
  if new_wins then
    assert.update_wins(arguments[1], nil)
  else
    assert.are_not.equal(last_win, vim.api.nvim_get_current_win())
    assert.update_wins({vim.api.nvim_get_current_win()}, nil)
  end

  return true
end

local function closed_win(_, arguments)
  local closed_wins = arguments[1]
  if closed_wins then
    assert.update_wins(nil, arguments[1])
  else
    -- inductive hypothesis: in addition to that of update_wins,
    -- last_win must be the window we were in immediately before closing
    assert.are_not.equal(last_win, vim.api.nvim_get_current_win())
    assert.update_wins(nil, {last_win})
  end

  return true
end

local function changed_win(state, _)
  -- no nested assertion to allow for negation
  local result = last_win ~= vim.api.nvim_get_current_win()
  if state.mod and result then last_win = vim.api.nvim_get_current_win() end

  return result
end


local function opened_infoview(_, arguments)
  local this_info = arguments[1]

  assert.is_truthy(this_info.is_open)
  assert.is_truthy(this_info.bufnr)
  assert.is_truthy(this_info.window)
  assert.is_falsy(this_info.prev_buf)
  assert.is_falsy(this_info.prev_win)

  return true
end

local function opened_infoview_kept(_, arguments)
  local this_info = arguments[1]

  assert.is_truthy(this_info.is_open)
  assert.is_truthy(this_info.bufnr)
  assert.is_truthy(this_info.window)
  assert.is_truthy(this_info.bufnr == this_info.prev_buf)
  assert.is_truthy(this_info.window == this_info.prev_win)

  return true
end

local function closed_infoview(_, arguments)
  local this_info = arguments[1]

  assert.is_falsy(this_info.is_open)
  assert.is_falsy(this_info.bufnr)
  assert.is_falsy(this_info.window)
  assert.is_truthy(this_info.prev_buf)
  assert.is_truthy(this_info.prev_win)

  return true
end

local function closed_infoview_kept(_, arguments)
  local this_info = arguments[1]

  assert.is_falsy(this_info.is_open)
  assert.is_falsy(this_info.bufnr)
  assert.is_falsy(this_info.window)
  assert.is_falsy(this_info.prev_buf)
  assert.is_falsy(this_info.prev_win)

  return true
end

local function infoview_check(list)
  local opened_wins = {}
  local closed_wins = {}

  for id, this_info in pairs(infoview._by_id) do
    local check = list[id]

    if not check then
      -- all unspecified infoviews must have previously been accounted for
      assert.is_truthy(this_info.prev_check)
      -- infer check
      if this_info.prev_check == "opened" then
        check = "opened_kept"
      elseif this_info.prev_check == "opened_kept" then
        check = "opened_kept"
      elseif this_info.prev_check == "closed" then
        check = "closed_kept"
      elseif this_info.prev_check == "closed_kept" then
        check = "closed_kept"
      end
    end

    if check == "opened" then
      vim.list_extend(opened_wins, {this_info.window})
      assert.opened_infoview_state(this_info)
    elseif check == "opened_kept" then
      assert.opened_infoview_kept_state(this_info)
    elseif check == "closed" then
      vim.list_extend(closed_wins, {this_info.prev_win})
      assert.closed_infoview_state(this_info)
    elseif check == "closed_kept" then
      assert.closed_infoview_kept_state(this_info)
    end

    this_info.prev_buf = this_info.bufnr
    this_info.prev_win = this_info.window
    this_info.prev_check = check
  end

  assert.update_wins(opened_wins, closed_wins)

  return true
end

assert:register("assertion", "has_all", has_all)
assert:register("assertion", "updated_infoviews", function(_, arguments)
  return infoview_check(arguments[1] or {})
end)
assert:register("assertion", "opened_infoview", function(_, arguments)
  return infoview_check(arguments[1] or {[vim.api.nvim_win_get_tabpage(0)] = "opened"})
end)
assert:register("assertion", "opened_infoview_kept", function(_, arguments)
  return infoview_check(arguments[1] or {[vim.api.nvim_win_get_tabpage(0)] = "opened_kept"})
end)
assert:register("assertion", "closed_infoview", function(_, arguments)
  return infoview_check(arguments[1] or {[vim.api.nvim_win_get_tabpage(0)] = "closed"})
end)
assert:register("assertion", "closed_infoview_kept", function(_, arguments)
  return infoview_check(arguments[1] or {[vim.api.nvim_win_get_tabpage(0)] = "closed_kept"})
end)
assert:register("assertion", "unopened_infoview", function(_, arguments)
  return infoview_check(arguments[1] or {[vim.api.nvim_win_get_tabpage(0)] = "closed_kept"})
end)

-- internal state checks
assert:register("assertion", "opened_infoview_state", opened_infoview)
assert:register("assertion", "opened_infoview_kept_state", opened_infoview_kept)
assert:register("assertion", "closed_infoview_state", closed_infoview)
assert:register("assertion", "closed_infoview_kept_state", closed_infoview_kept)

assert:register("assertion", "update_wins", update_wins)
assert:register("assertion", "closed_win", closed_win)
assert:register("assertion", "created_win", created_win)
assert:register("assertion", "changed_win", changed_win)

-- initialize on very first nvim window (base case satisfied pretty trivially)
assert.created_win()

return helpers
