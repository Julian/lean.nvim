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

local last_handles = {["win"] = {}, ["buf"] = {}}
local last_handle = {["win"] = nil, ["buf"] = nil}
local last_handle_max = {["win"] = -1, ["buf"] = -1}

local handle_current = function(htype)
  if htype == "win" then return vim.api.nvim_get_current_win() end
  if htype == "buf" then return vim.api.nvim_get_current_buf() end
end

local handle_list = function(htype)
  if htype == "win" then return vim.api.nvim_list_wins() end
  if htype == "buf" then return vim.api.nvim_list_bufs() end
end

local handle_valid = function(htype, handle)
  if htype == "win" then return vim.api.nvim_win_is_valid(handle) end
  if htype == "buf" then return vim.api.nvim_buf_is_valid(handle) end
end

local function get_handles(htype)
  local handles = {}
  for _, handle in pairs(handle_list(htype)) do
    handles[handle] = true
  end

  return handles
end

local function update_handles(htype, opened_handles, closed_handles)
  -- inductive hypothesis: last_handles is accurate to immediately before creating/closing any of the given handles
  local expected_handles = vim.deepcopy(last_handles[htype])

  opened_handles = opened_handles or {}
  closed_handles = closed_handles or {}

  -- for ensuring no collisions
  local opened_handle_set = {}

  for _, opened_handle in pairs(opened_handles) do
    -- should be an actual handle
    assert.is_truthy(handle_valid(htype, opened_handle))

    -- should be brand new
    assert.is_truthy(opened_handle > last_handle_max[htype])
    assert.is_falsy(opened_handle_set[opened_handle])

    expected_handles[opened_handle] = true
    opened_handle_set[opened_handle] = true
  end

  for _, closed_handle in pairs(closed_handles) do
    -- should not be a handle
    assert.is_falsy(handle_valid(htype, closed_handle))

    -- should have previously existed (should not pass a random previously/never closed handle)
    assert.is_truthy(last_handles[htype][closed_handle])

    expected_handles[closed_handle] = nil
  end

  assert.message("expected: " .. vim.inspect(expected_handles) .. "\n got: "
    .. vim.inspect(get_handles(htype))).is_truthy(vim.deep_equal(expected_handles, get_handles(htype)))

  for _, opened_handle in pairs(opened_handles) do
    if opened_handle > last_handle_max[htype] then last_handle_max[htype] = opened_handle end
  end

  -- maintain IH
  last_handles[htype] = get_handles(htype)

  -- also maintain IH for closed_handle
  last_handle[htype] = handle_current(htype)

  return true
end

local function created_handle(htype, new_handles)
  if new_handles then
    return update_handles(htype, new_handles, nil)
  else
    assert.are_not.equal(last_handle[htype], handle_current(htype))
    return update_handles(htype, {handle_current(htype)}, nil)
  end
end

local function closed_handle(htype, closed_handles)
  if closed_handles then
    return update_handles(htype, nil, closed_handles)
  else
    -- inductive hypothesis: in addition to that of update_handles,
    -- last_handle must be the handledow we were in immediately before closing
    assert.are_not.equal(last_handle[htype], handle_current(htype))
    return update_handles(htype, nil, {last_handle[htype]})
  end
end

local function changed_handle(htype, opened_handles, closed_handles)
  assert.are_not.equal(last_handle[htype], handle_current(htype))

  return update_handles(htype, opened_handles, closed_handles)
end

local function kept_handle(htype, opened_handles, closed_handles)
  assert.are_equal(last_handle[htype], handle_current(htype))

  return update_handles(htype, opened_handles, closed_handles)
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

local last_info_ids = {}

local function infoview_check(list, check_win, check_buf)
  local opened_wins = {}
  local closed_wins = {}
  local opened_bufs = {}
  local closed_bufs = {}

  local info_ids = {}

  for id, this_info in pairs(infoview._by_id) do
    local check = list[id]

    if not check then
      -- all unspecified infoviews must have been previously checked
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
      -- in case window/buffer opened already checked
      if check_win then vim.list_extend(opened_wins, {this_info.window}) end
      if check_buf then vim.list_extend(opened_bufs, {this_info.bufnr}) end
      assert.opened_infoview_state(this_info)
    elseif check == "opened_kept" then
      assert.opened_infoview_kept_state(this_info)
    elseif check == "closed" then
      -- in case window/buffer closed already checked
      if check_win then vim.list_extend(closed_wins, {this_info.prev_win}) end
      if check_buf then vim.list_extend(closed_bufs, {this_info.prev_buf}) end
      assert.closed_infoview_state(this_info)
    elseif check == "closed_kept" then
      assert.closed_infoview_kept_state(this_info)
    end

    this_info.prev_buf = this_info.bufnr
    this_info.prev_win = this_info.window
    this_info.prev_check = check

    info_ids[id] = true
  end

  -- all previous infoviews must have been checked
  for id, _ in pairs(last_info_ids) do assert.is_truthy(info_ids[id]) end

  -- all specified infoviews must have been checked
  for id, _ in pairs(list) do assert.is_truthy(info_ids[id]) end

  last_info_ids = info_ids

  assert.update_wins(opened_wins, closed_wins)
  assert.update_bufs(opened_bufs, closed_bufs)

  return true
end

local function get_infoview_assertion(check, check_win, check_buf)
  if check_win == nil then check_win = true end
  if check_buf == nil then check_buf = true end

  return function(_, arguments)
    local check_map = {}
    local list = arguments[1] or {vim.api.nvim_win_get_tabpage(0)}
    for _, id in pairs(list) do
      check_map[id] = check
    end
    return infoview_check(check_map, check_win, check_buf)
  end
end

assert:register("assertion", "has_all", has_all)
assert:register("assertion", "updated_infoviews", function(_, arguments)
  local check_win, check_buf
  if arguments[2] == nil then check_win = true end
  if arguments[3] == nil then check_buf = true end
  return infoview_check(arguments[1] or {}, check_win, check_buf)
end)
assert:register("assertion", "opened_infoview_win", get_infoview_assertion("opened", true, false))
assert:register("assertion", "opened_infoview_buf", get_infoview_assertion("opened", false, true))
assert:register("assertion", "opened_infoview_none", get_infoview_assertion("opened", false, false))
assert:register("assertion", "opened_infoview", get_infoview_assertion("opened"))
assert:register("assertion", "opened_infoview_kept", get_infoview_assertion("opened_kept"))
assert:register("assertion", "closed_infoview_win", get_infoview_assertion("closed", true, false))
assert:register("assertion", "closed_infoview_buf", get_infoview_assertion("closed", false, true))
assert:register("assertion", "closed_infoview_none", get_infoview_assertion("closed", false, false))
assert:register("assertion", "closed_infoview", get_infoview_assertion("closed"))
assert:register("assertion", "closed_infoview_kept", get_infoview_assertion("closed_kept"))
assert:register("assertion", "unopened_infoview", get_infoview_assertion("closed_kept"))

-- internal state checks
assert:register("assertion", "opened_infoview_state", opened_infoview)
assert:register("assertion", "opened_infoview_kept_state", opened_infoview_kept)
assert:register("assertion", "closed_infoview_state", closed_infoview)
assert:register("assertion", "closed_infoview_kept_state", closed_infoview_kept)

for _, htype in pairs({"buf", "win"}) do
  assert:register("assertion", "update_" .. htype .. "s", function (_, arguments)
    return update_handles(htype, arguments[1], arguments[2])
  end)
  assert:register("assertion", "closed_" .. htype, function (_, arguments)
    return closed_handle(htype, arguments[1])
  end)
  assert:register("assertion", "created_" .. htype, function (_, arguments)
    return created_handle(htype, arguments[1])
  end)
  assert:register("assertion", "changed_" .. htype, function (_, arguments)
    return changed_handle(htype, arguments[1], arguments[2])
  end)
  assert:register("assertion", "kept_" .. htype, function (_, arguments)
    return kept_handle(htype, arguments[1], arguments[2])
  end)
end

-- initialize on very first nvim window/buffer (base case satisfied pretty trivially)
assert.created_win()
assert.created_buf()

return helpers
