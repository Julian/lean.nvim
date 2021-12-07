local assert = require('luassert')
local infoview = require('lean.infoview')
local progress = require'lean.progress'

local lean = require('lean')
local fixtures = require'tests.fixtures'

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
    autoopen = false,
    autopause = true,
    show_processing = false,
    show_no_info_message = true,
    lean3 = { show_filter = false },
    reuse_info = false,
  },
  stderr = { enable = false },
  lsp3 = {
    enable = false
  },
  lsp = {
    enable = false
  }
}

function helpers.setup(config)
  -- initialize on very first nvim window/buffer (base case satisfied pretty trivially)
  assert.win.created.tracked()
  assert.buf.created.tracked()
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
local function set_unique_name_so_we_always_have_a_separate_fake_file(bufnr, ft)
  local counter = helpers._clean_buffer_counter
  helpers._clean_buffer_counter = helpers._clean_buffer_counter + 1
  local unique_name =
    ft == 'lean3' and string.format('unittest-%d.lean', counter)
                   or string.format('%s/unittest-%d.lean', fixtures.lean_project.path, counter)
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
    set_unique_name_so_we_always_have_a_separate_fake_file(bufnr, ft)
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
    --vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

--- Wait a few seconds for line diagnostics, erroring if none arrive.
function helpers.wait_for_line_diagnostics()
  local succeeded, _ = vim.wait(5000, function()
    if progress.is_processing(vim.uri_from_bufnr(0)) then return false end
    local diags = vim.diagnostic ~= nil
      and -- neovim 0.6
        vim.diagnostic.get(0, {lnum = vim.api.nvim_win_get_cursor(0)[1] - 1})
      or -- neovim 0.5
        vim.lsp.diagnostic.get_line_diagnostics()

    -- Lean 4 sends file progress notification too late :-(
    if #diags == 1 then
      local msg = diags[1].message
      if msg:match("^configuring ") then return false end
      if msg:match("^Foo: ") then return false end
      if msg:match("^> ") then return false end
    end

    return #diags > 0
  end)
  assert.message("Waited for line diagnostics but none came.").True(succeeded)
end

function helpers.wait_for_filetype()
  local result, _ = vim.wait(10000, function()
    return require"lean".is_lean_buffer()
  end)
  assert.message("never got filetype").is_truthy(result)
end

function helpers.edit_lean_buffer(filename)
  vim.api.nvim_command("edit! " .. filename)
  helpers.wait_for_filetype()
end

--- Wait a few seconds for server progress to complete on the current buffer, erroring if it doesn't.
function helpers.wait_for_server_progress()
  -- the first fileProgress notification should come within this time,
  -- so we avoid the initial nil case (for backwards compatibility)
  vim.wait(5000)
  local succeeded, _ = vim.wait(10000, function()
    return not require"lean.progress".is_processing(
      vim.uri_from_bufnr(vim.api.nvim_get_current_buf()))
  end)
  assert.message("Waited for server progress to complete but never did.").True(succeeded)
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

  if type(text) == "table" then text = table.concat(text, "\n") end
  local expected = arguments[2]
  for _, string in pairs(expected) do
    assert.has_match(string, text, nil, true)
  end
  return true
end

assert:register("assertion", "has_all", has_all)

--- The number of current windows.
function helpers.get_num_wins() return #vim.api.nvim_list_wins() end

local NVIM_PREFIX = "nvim_handle_tracker_"
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
  if htype == "win" then return handle and vim.api.nvim_win_is_valid(handle) end
  if htype == "buf" then return handle and vim.api.nvim_buf_is_valid(handle) end
end

local function to_set(list)
  local set = {}
  for _, item in pairs(list) do
    set[item] = true
  end

  return set
end

local function get_handles(htype) return to_set(handle_list(htype)) end

local tracked_pending_state = {}

local function track_pending_handles(state, _)
  local htype = rawget(state, NVIM_PREFIX .. "htype")
  assert.message("must specify handle type").is_not_nil(htype)

  -- enforce only calling once (for readability)
  assert.message("pending tracker assertion state should be set only once").is_nil(tracked_pending_state[htype])
  -- must apply .use_pending modifier to actual tracked() call (for readability)
  assert.message(".use_pending should only be used on an actual tracked() assertion").is_nil(
    rawget(state, NVIM_PREFIX .. "use_pending"))

  tracked_pending_state[htype] = state
  return true
end

local function to_string_idx(tbl)
  local new = {}
  for key, value in pairs(tbl) do new[tostring(key)] = value end
  return new
end

local function to_num_idx(tbl)
  local new = {}
  for key, value in pairs(tbl) do new[tonumber(key)] = value end
  return new
end

local function track_handles(state, _)
  -- inductive hypothesis: last_handles and last_handle are accurate
  -- to immediately before creating/closing any of the given handles

  local htype = rawget(state, NVIM_PREFIX .. "htype")
  assert.is_not_nil(htype)

  if rawget(state, NVIM_PREFIX .. "use_pending") then
    assert.message("no pending tracker assertion state set").is_not_nil(tracked_pending_state[htype])
    state = vim.tbl_deep_extend("keep", state, tracked_pending_state[htype])
    tracked_pending_state[htype] = nil
  else
    assert.message("ignored pending tracker assertion state").is_nil(tracked_pending_state[htype])
  end

  local changed = rawget(state, NVIM_PREFIX .. "changed") or false

  local opened_handles = rawget(state, NVIM_PREFIX .. "created")
  opened_handles = opened_handles or {}
  opened_handles = to_num_idx(opened_handles)

  local closed_handles = rawget(state, NVIM_PREFIX .. "removed") or {}
  closed_handles = closed_handles or {}
  closed_handles = to_num_idx(closed_handles)

  if changed then
    assert.are_not.equal(last_handle[htype], handle_current(htype))
  else
    assert.equal(last_handle[htype], handle_current(htype))
  end

  local expected_handles = vim.deepcopy(last_handles[htype])

  -- for ensuring no collisions
  local opened_handle_set = {}

  for opened_handle, _ in pairs(opened_handles) do
    -- should be an actual handle
    assert.is_truthy(handle_valid(htype, opened_handle))

    -- should be brand new
    assert.is_truthy(opened_handle > last_handle_max[htype])
    assert.is_falsy(opened_handle_set[opened_handle])

    expected_handles[opened_handle] = true
    opened_handle_set[opened_handle] = true
  end

  for closed_handle, _ in pairs(closed_handles) do
    -- should not be a handle
    assert.is_falsy(handle_valid(htype, closed_handle))

    -- should have previously existed (should not pass a random previously/never removed handle)
    assert.is_truthy(last_handles[htype][closed_handle])

    expected_handles[closed_handle] = nil
  end

  assert.message("expected: " .. vim.inspect(expected_handles) .. "\n got: "
    .. vim.inspect(get_handles(htype))).is_truthy(vim.deep_equal(expected_handles, get_handles(htype)))

  for opened_handle, _ in pairs(opened_handles) do
    if opened_handle > last_handle_max[htype] then last_handle_max[htype] = opened_handle end
  end

  -- maintain IH
  last_handles[htype] = get_handles(htype)
  last_handle[htype] = handle_current(htype)

  return true
end

assert:register("modifier", "win", function(state, _, _) rawset(state, NVIM_PREFIX .. "htype", "win") end)
assert:register("modifier", "buf", function(state, _, _) rawset(state, NVIM_PREFIX .. "htype", "buf") end)

assert:register("modifier", "created", function(state, arguments, _)
  local created = rawget(state, NVIM_PREFIX .. "created") or {}
  if arguments and arguments[1] then
    created = vim.tbl_extend("keep", to_string_idx(to_set(arguments[1])), created)
  else
    created = vim.tbl_extend("keep", to_string_idx{[handle_current(rawget(state, NVIM_PREFIX .. "htype"))]
    = true}, created)
    rawset(state, NVIM_PREFIX .. "changed", true)
  end
  rawset(state, NVIM_PREFIX .. "created", created)
end)
assert:register("modifier", "removed", function(state, arguments, _)
  local removed = rawget(state, NVIM_PREFIX .. "removed") or {}
  if arguments and arguments[1] then
    removed = vim.tbl_extend("keep", to_string_idx(to_set(arguments[1])), removed)
  else
    removed = vim.tbl_extend("keep", to_string_idx{[last_handle[rawget(state, NVIM_PREFIX .. "htype")]] = true},
      removed)
    rawset(state, NVIM_PREFIX .. "changed", true)
  end
  rawset(state, NVIM_PREFIX .. "removed", removed)
end)

assert:register("modifier", "stayed", function(state, _, _)
  rawset(state, NVIM_PREFIX .. "changed", false)
end)
assert:register("modifier", "left", function(state, _, _)
  rawset(state, NVIM_PREFIX .. "changed", true)
end)
assert:register("modifier", "use_pending", function(state, _, _)
  rawset(state, NVIM_PREFIX .. "use_pending", true)
end)

assert:register("assertion", "tracked_pending", track_pending_handles)
assert:register("assertion", "tracked", track_handles)

local last_infoview_ids = {}
local last_info_ids = {}
local last_pin_ids = {}

local function opened_initialized_infoview(_, arguments)
  local this_infoview = arguments[1]

  assert.is_nil(last_infoview_ids[this_infoview.id])

  assert.is_truthy(this_infoview.is_open)
  assert.is_truthy(this_infoview.window)
  assert.is_falsy(this_infoview.prev_win)
  assert.is_truthy(this_infoview.info.id)
  assert.is_falsy(this_infoview.prev_info)

  return true
end

local function closed_initialized_infoview(_, arguments)
  local this_infoview = arguments[1]

  assert.is_nil(last_infoview_ids[this_infoview.id])

  assert.is_falsy(this_infoview.is_open)
  assert.is_falsy(this_infoview.window)
  assert.is_falsy(this_infoview.prev_win)
  assert.is_truthy(this_infoview.info.id)
  assert.is_falsy(this_infoview.prev_info)

  return true
end

local function opened_infoview(_, arguments)
  local this_infoview = arguments[1]

  assert.is_truthy(this_infoview.is_open)
  assert.is_truthy(this_infoview.window)
  assert.is_falsy(this_infoview.prev_win)
  assert.is_truthy(this_infoview.info.id)
  assert.are_equal(this_infoview.info.id, this_infoview.prev_info)

  return true
end

local function opened_infoview_kept(_, arguments)
  local this_infoview = arguments[1]

  assert.is_truthy(this_infoview.is_open)
  assert.is_truthy(this_infoview.window)
  assert.are_equal(this_infoview.window, this_infoview.prev_win)
  assert.is_truthy(this_infoview.info.id)
  assert.are_equal(this_infoview.info.id, this_infoview.prev_info)

  return true
end

local function closed_infoview(_, arguments)
  local this_infoview = arguments[1]

  assert.is_falsy(this_infoview.is_open)
  assert.is_falsy(this_infoview.window)
  assert.is_truthy(this_infoview.prev_win)
  assert.is_truthy(this_infoview.info.id)
  assert.are_equal(this_infoview.info.id, this_infoview.prev_info)

  return true
end

local function closed_infoview_kept(_, arguments)
  local this_infoview = arguments[1]

  assert.is_falsy(this_infoview.is_open)
  assert.is_falsy(this_infoview.window)
  assert.is_falsy(this_infoview.prev_win)
  assert.is_truthy(this_infoview.info.id)
  assert.are_equal(this_infoview.info.id, this_infoview.prev_info)

  return true
end

local function opened_info(_, arguments)
  local this_info = arguments[1]

  assert.is_nil(last_info_ids[this_info.id])

  assert.is_truthy(this_info.bufdiv)
  assert.is_falsy(this_info.prev_buf)

  return true
end

local function opened_info_kept(_, arguments)
  local this_info = arguments[1]

  assert.is_truthy(this_info.bufdiv)
  assert.are_equal(this_info.bufdiv.buf, this_info.prev_buf)

  return true
end

local function opened_pin(_, arguments)
  local this_pin = arguments[1]

  assert.is_nil(last_pin_ids[this_pin.id])
  assert.is_nil(this_pin.prev_div)

  return true
end

local function opened_pin_kept(_, arguments)
  local this_pin = arguments[1]

  assert.is_not_nil(last_pin_ids[this_pin.id])

  return true
end

local LEAN_NVIM_PREFIX = "lean_nvim_infoview_tracker_"

local checks = {"opened", "initopened", "opened_kept", "closed", "initclosed", "closed_kept"}
local win_checks = {"diffwinopened", "diffwinclosed"}
local info_checks = {"infoopened", "infoopened_kept"}
local pin_checks = {"pinopened", "pinopened_kept", "pindeleted"}
local pin_text_checks = {"pin_text_changed", "pin_text_kept"}
local pin_pos_checks = {"pin_pos_changed", "pin_pos_kept"}

for _, check in pairs(checks) do
  assert:register("modifier", check, function(state, arguments)
    rawset(state, LEAN_NVIM_PREFIX .. check, arguments and arguments[1] or {infoview.get_current_infoview().id})
  end)
end

for _, check in pairs(win_checks) do
  assert:register("modifier", check, function(state, arguments)
    rawset(state, LEAN_NVIM_PREFIX .. check, arguments and arguments[1] or {infoview.get_current_infoview().id})
  end)
end

for _, check in pairs(info_checks) do
  assert:register("modifier", check, function(state, arguments)
    rawset(state, LEAN_NVIM_PREFIX .. check, arguments and arguments[1]
      or {infoview.get_current_infoview().info.id})
  end)
end

for _, check in pairs(pin_checks) do
  assert:register("modifier", check, function(state, arguments)
    rawset(state, LEAN_NVIM_PREFIX .. check, arguments and arguments[1]
      or {infoview.get_current_infoview().info.pin.id})
  end)
end

for _, check in pairs(pin_text_checks) do
  assert:register("modifier", check, function(state, arguments)
    rawset(state, LEAN_NVIM_PREFIX .. check, arguments and arguments[1]
      or {infoview.get_current_infoview().info.pin.id})
  end)
end

for _, check in pairs(pin_pos_checks) do
  assert:register("modifier", check, function(state, arguments)
    rawset(state, LEAN_NVIM_PREFIX .. check, arguments and arguments[1]
      or {infoview.get_current_infoview().info.pin.id})
  end)
end

assert:register("modifier", "use_pendingbuf", function(state, _, _)
  rawset(state, LEAN_NVIM_PREFIX .. "buf_use_pending", true)
end)
assert:register("modifier", "use_pendingwin", function(state, _, _)
  rawset(state, LEAN_NVIM_PREFIX .. "win_use_pending", true)
end)

local function infoview_check(state, _)
  local infoview_list = {}
  local infoview_win_list = {}
  local info_list = {}
  local pin_list = {}
  local pin_text_list = {}
  local pin_pos_list = {}

  for _, check in pairs(checks) do
    local handles = rawget(state, LEAN_NVIM_PREFIX .. check) or {}
    for _, id in pairs(handles) do
      assert.is_nil(infoview_list[id])
      infoview_list[id] = check
    end
  end

  for _, check in pairs(win_checks) do
    local handles = rawget(state, LEAN_NVIM_PREFIX .. check) or {}
    for _, id in pairs(handles) do
      infoview_win_list[id] = infoview_win_list[id] or {}
      assert.is_nil(infoview_win_list[id][check])
      infoview_win_list[id][check] = true
    end
  end

  for _, check in pairs(info_checks) do
    local handles = rawget(state, LEAN_NVIM_PREFIX .. check) or {}
    for _, id in pairs(handles) do
      assert.is_nil(info_list[id])
      info_list[id] = check
    end
  end

  for _, check in pairs(pin_checks) do
    local handles = rawget(state, LEAN_NVIM_PREFIX .. check) or {}
    for _, id in pairs(handles) do
      assert.is_nil(pin_list[id])
      pin_list[id] = check
    end
  end

  for _, check in pairs(pin_text_checks) do
    local handles = rawget(state, LEAN_NVIM_PREFIX .. check) or {}
    for _, id in pairs(handles) do
      assert.is_nil(pin_text_list[id])
      pin_text_list[id] = check
    end
  end

  for _, check in pairs(pin_pos_checks) do
    local handles = rawget(state, LEAN_NVIM_PREFIX .. check) or {}
    for _, id in pairs(handles) do
      assert.is_nil(pin_pos_list[id])
      pin_pos_list[id] = check
    end
  end

  local opened_wins = {}
  local closed_wins = {}
  local opened_bufs = {}
  local closed_bufs = {}

  local infoview_ids = {}
  local info_ids = {}
  local pin_ids = {}

  --- INFOVIEW CHECK

  for id, this_infoview in pairs(infoview._by_id) do
    local check = infoview_list[id]
    local win_check = infoview_win_list[id] or {}

    if not check then
      -- all unspecified infoviews must have been previously checked
      assert.is_truthy(this_infoview.prev_check)
      -- infer check
      if this_infoview.prev_check == "opened" then
        check = "opened_kept"
      elseif this_infoview.prev_check == "initopened" then
        check = "opened_kept"
      elseif this_infoview.prev_check == "opened_kept" then
        check = "opened_kept"
      elseif this_infoview.prev_check == "closed" then
        check = "closed_kept"
      elseif this_infoview.prev_check == "initclosed" then
        check = "closed_kept"
      elseif this_infoview.prev_check == "closed_kept" then
        check = "closed_kept"
      end
    end

    if check == "opened" then
      vim.list_extend(opened_wins, {this_infoview.window})
      assert.opened_infoview_state(this_infoview)
    elseif check == "initopened" then
      vim.list_extend(opened_wins, {this_infoview.window})
      assert.opened_initialized_infoview_state(this_infoview)
      assert.is_nil(info_list[this_infoview.info.id])
      info_list[this_infoview.info.id] = "infoopened"
      assert.is_nil(pin_pos_list[this_infoview.info.pin.id])
      pin_pos_list[this_infoview.info.pin.id] = "pin_pos_kept"
    elseif check == "opened_kept" then
      assert.opened_infoview_kept_state(this_infoview)
    elseif check == "closed" then
      vim.list_extend(closed_wins, {this_infoview.prev_win})
      assert.closed_infoview_state(this_infoview)
    elseif check == "initclosed" then
      assert.closed_initialized_infoview_state(this_infoview)
      assert.is_nil(info_list[this_infoview.info.id])
      info_list[this_infoview.info.id] = "infoopened"
      assert.is_nil(pin_pos_list[this_infoview.info.pin.id])
      pin_pos_list[this_infoview.info.pin.id] = "pin_pos_kept"
    elseif check == "closed_kept" then
      assert.closed_infoview_kept_state(this_infoview)
    end

    if win_check["diffwinopened"] then
      assert.is_nil(this_infoview.prev_diff_win)
      assert.is_not_nil(this_infoview.diff_win)
      vim.list_extend(opened_wins, {this_infoview.diff_win})
    elseif win_check["diffwinclosed"] then
      assert.is_not_nil(this_infoview.prev_diff_win)
      assert.is_nil(this_infoview.diff_win)
      vim.list_extend(closed_wins, {this_infoview.prev_diff_win})
    end

    this_infoview.prev_info = this_infoview.info.id
    this_infoview.prev_win = this_infoview.window
    this_infoview.prev_check = check

    this_infoview.prev_diff_win = this_infoview.diff_win

    infoview_ids[id] = true
  end

  -- all previous infoviews must have been checked
  for id, _ in pairs(last_infoview_ids) do assert.is_truthy(infoview_ids[id]) end

  -- all specified infoviews must have been checked
  for id, _ in pairs(infoview_list) do assert.is_truthy(infoview_ids[id]) end

  last_infoview_ids = infoview_ids

  ---

  --- INFO CHECK

  for id, this_info in pairs(infoview._info_by_id) do
    local check = info_list[id]

    if not check then
      -- all unspecified infos must have been previously checked
      assert.is_truthy(this_info.prev_check)
      -- infer check
      check = "infoopened_kept"
    end

    if check == "infoopened" then
      vim.list_extend(opened_bufs, {this_info.bufdiv.buf, this_info.diff_bufdiv.buf})
      assert.opened_info_state(this_info)
      assert.is_nil(pin_list[this_info.pin.id])
      pin_list[this_info.pin.id] = "pinopened"
    else
      assert.opened_info_kept_state(this_info)
    end

    this_info.prev_buf = this_info.bufdiv.buf
    this_info.prev_check = check

    info_ids[id] = true
  end

  -- all previous infos must have been checked
  for id, _ in pairs(last_info_ids) do assert.is_truthy(info_ids[id]) end

  -- all specified infos must have been checked
  for id, _ in pairs(info_list) do assert.is_truthy(info_ids[id]) end

  last_info_ids = info_ids

  ---

  --- PIN CHECK

  for id, this_pin in pairs(infoview._pin_by_id) do

    -- EXISTENCE CHECK

    local check = pin_list[id]

    if not check then
      -- all unspecified pins must have been previously checked
      assert.is_truthy(this_pin.prev_check)
      -- infer check
      check = "pinopened_kept"
    end

    if check == "pinopened" then
      assert.opened_pin_state(this_pin)
      this_pin.prev_div_text = this_pin.div:to_string()
      this_pin.prev_position_params = vim.deepcopy(this_pin.__position_params)
      -- assume text and pos kept if unspecified
      if pin_text_list[id] == nil then
        pin_text_list[id] = "pin_text_kept"
      end
      if pin_pos_list[id] == nil then
        pin_pos_list[id] = "pin_pos_kept"
      end
    elseif check == "pinopened_kept" then
      assert.opened_pin_kept_state(this_pin)
    else
      assert.message("encountered deleted pin").is_truthy(false)
    end

    this_pin.prev_check = check

    --

    local function check_change(get_before, get_after, change, type)
      local changed, _ = vim.wait(change and 500 or 150, function()
        return not vim.deep_equal(get_before(), get_after())
      end, 50)
      if change then
        assert.message("expected pin " .. tostring(id) .. " " .. type .. " change but did not occur:"
          .. vim.inspect(get_before())).is_truthy(changed)
      else
        assert.message("expected pin " .. tostring(id) .. " " .. type .. " not to change but did change\nbefore: "
          .. vim.inspect(get_before()) .. "\nafter: "
          .. vim.inspect(get_after())).is_falsy(changed)
      end
    end

    -- POSITION CHECK

    local pos_check = pin_pos_list[id]

    if not pos_check then
      assert.is_truthy(this_pin.prev_pos_check)
      -- infer pos check
      pos_check = "pin_pos_kept"
    end

    if pos_check == "pin_pos_changed" then
      check_change(function() return this_pin.prev_position_params end,
        function() return this_pin.__position_params end, true, "position")
    else
      check_change(function() return this_pin.prev_position_params end,
        function() return this_pin.__position_params end, false, "position")
    end

    this_pin.prev_position_params = vim.deepcopy(this_pin.__position_params)
    this_pin.prev_pos_check = pos_check

    --

    -- TEXT CHECK

    local text_check = pin_text_list[id]

    if not text_check then
      assert.is_truthy(this_pin.prev_text_check)
      -- infer text check
      text_check = "pin_text_kept"
    end

    if text_check == "pin_text_changed" then
      check_change(function() return this_pin.prev_div_text end,
        function() return this_pin.div:to_string() end, true, "text")
    else
      check_change(function() return this_pin.prev_div_text end,
        function() return this_pin.div:to_string() end, false, "text")
    end

    this_pin.prev_div_text = this_pin.div:to_string()
    this_pin.prev_text_check = text_check

    pin_ids[id] = true

    --

  end

  -- all previous undeleted pins must have been checked
  for id, _ in pairs(last_pin_ids) do
    if pin_list[id] ~= "pindeleted" then
      assert.is_truthy(pin_ids[id])
    end
  end

  -- all specified pins must have been checked
  for id, _ in pairs(pin_list) do
    if pin_list[id] == "pindeleted" then
      assert.truthy(last_pin_ids[id])
      assert.is_falsy(pin_ids[id])
    else
      assert.is_truthy(pin_ids[id])
    end
  end

  last_pin_ids = pin_ids

  ---

  if rawget(state, LEAN_NVIM_PREFIX .. "win_use_pending") then
    assert.win.use_pending.removed(closed_wins).created(opened_wins).tracked()
  else
    assert.win.removed(closed_wins).created(opened_wins).tracked()
  end
  if rawget(state, LEAN_NVIM_PREFIX .. "buf_use_pending") then
    assert.buf.use_pending.removed(closed_bufs).created(opened_bufs).tracked()
  else
    assert.buf.removed(closed_bufs).created(opened_bufs).tracked()
  end

  return true
end

assert:register("assertion", "infoview", infoview_check)

-- internal state checks
assert:register("assertion", "opened_infoview_state", opened_infoview)
assert:register("assertion", "opened_initialized_infoview_state", opened_initialized_infoview)
assert:register("assertion", "opened_info_state", opened_info)
assert:register("assertion", "opened_pin_state", opened_pin)
assert:register("assertion", "opened_infoview_kept_state", opened_infoview_kept)
assert:register("assertion", "opened_info_kept_state", opened_info_kept)
assert:register("assertion", "opened_pin_kept_state", opened_pin_kept)
assert:register("assertion", "closed_infoview_state", closed_infoview)
assert:register("assertion", "closed_initialized_infoview_state", closed_initialized_infoview)
assert:register("assertion", "closed_infoview_kept_state", closed_infoview_kept)

return helpers
