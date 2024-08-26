local assert = require 'luassert'

local fixtures = require 'spec.fixtures'
local infoview = require 'lean.infoview'
local progress = require 'lean.progress'
local util = require 'lean._util'

local helpers = { _clean_buffer_counter = 1 }

--- Feed some keystrokes into the current buffer, replacing termcodes.
function helpers.feed(text, feed_opts)
  feed_opts = feed_opts or 'mtx'
  local to_feed = vim.api.nvim_replace_termcodes(text, true, false, true)
  vim.api.nvim_feedkeys(to_feed, feed_opts, true)
end

--- Insert some text into the current buffer.
function helpers.insert(text, feed_opts)
  feed_opts = feed_opts or 'x'
  helpers.feed('i' .. text, feed_opts)
end

function helpers.all_lean_extmarks(buffer, start, end_)
  local extmarks = {}
  for namespace, ns_id in pairs(vim.api.nvim_get_namespaces()) do
    if namespace:match '^lean.' then
      vim.list_extend(
        extmarks,
        vim.api.nvim_buf_get_extmarks(buffer, ns_id, start, end_, { details = true })
      )
    end
  end
  return extmarks
end

--- Move the cursor to a new location.
---
--- Ideally this function wouldn't exist, and one would call
--- `vim.api.nvim_win_set_cursor` directly, but it does not fire `CursorMoved`
--- autocmds. This function exists therefore to make tests which have slightly
--- less implementation details in them (the manual firing of that autocmd).
---
---@param opts MoveCursorOpts
function helpers.move_cursor(opts)
  local window = opts.window or 0

  assert
    .message(util.s [[
    Cursor is already at %s.
    If you just want to ensure the cursor is at this location,
    use nvim_win_set_cursor directly.
  ]]).are_not
    .same(opts.to, vim.api.nvim_win_get_cursor(window))

  vim.api.nvim_win_set_cursor(window, opts.to)
  vim.cmd.doautocmd 'CursorMoved'
end

---@class MoveCursorOpts
---@field window? integer @the window handle. Defaults to the current window.
---@field to table @the new cursor position (1-row indexed, as per nvim_win_set_cursor)

--- Wait for all of the pins associated with the given infoview to finish loading/processing.
---@param iv? Infoview
function helpers.wait_for_loading_pins(iv)
  iv = iv or infoview.get_current_infoview()
  if not iv then
    error 'Infoview is not open!'
  end
  local info = iv.info
  local last, last_loading, last_processing
  local succeeded, _ = vim.wait(7000, function()
    for _, pin in pairs(vim.list_extend({ info.pin, info.__diff_pin }, info.pins)) do
      local processing = pin.__position_params
        and require('lean.progress').test_is_processing_at(pin.__position_params)
      if pin.loading or processing then
        last = pin.id
        last_loading = pin.loading
        last_processing = processing
        return false
      end
    end
    return true
  end)
  local msg = last_loading and 'loading' or ''
  if last_loading and last_processing then
    msg = msg .. '/'
  end
  msg = msg .. (last_processing and 'processing' or '')
  assert
    .message(string.format('Pin %s never finished %s.', tostring(last) or '', msg))
    .True(succeeded)
end

function helpers.wait_for_ready_lsp()
  local succeeded, _ = vim.wait(15000, function()
    return not not vim.lsp.buf_notify(0, '$/progress', {})
  end)
  assert.message('LSP server was never ready.').True(succeeded)
end

---Wait until a window that isn't one of the known ones shows up.
---@param known table
function helpers.wait_for_new_window(known)
  local new_window
  local succeeded = vim.wait(1000, function()
    for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if not vim.tbl_contains(known, window) then
        new_window = window
        return true
      end
    end
  end)
  assert.message('Never found a new window').is_true(succeeded)
  return new_window
end

-- Even though we can delete a buffer, so should be able to reuse names,
-- we do this to ensure if a test fails, future ones still get new "files".
local function set_unique_name_so_we_always_have_a_separate_fake_file(bufnr)
  local counter = helpers._clean_buffer_counter
  helpers._clean_buffer_counter = helpers._clean_buffer_counter + 1
  local unique_name = string.format('%s/unittest-%d.lean', fixtures.project.path, counter)
  vim.api.nvim_buf_set_name(bufnr, unique_name)
end

--- Create a clean Lean buffer with the given contents.
--
--  Waits for the LSP to be ready before proceeding with a given callback.
--
--  Yes c(lean) may be a double entendre, and no I don't feel bad.
function helpers.clean_buffer(contents, callback)
  local lines

  -- Support a 1-arg version where we assume the contents is an empty buffer.
  if callback == nil then
    callback = contents
    lines = {}
  else
    lines = vim.split(util.dedent(contents:gsub('^\n', '')):gsub('\n$', ''), '\n')
  end

  return function()
    local bufnr = vim.api.nvim_create_buf(false, false)
    set_unique_name_so_we_always_have_a_separate_fake_file(bufnr)
    -- apparently necessary to trigger BufWinEnter
    vim.api.nvim_set_current_buf(bufnr)
    vim.bo.bufhidden = 'hide'
    vim.bo.swapfile = false
    vim.bo.filetype = 'lean'

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_call(bufnr, function()
      callback { source_file = { bufnr = bufnr } }
    end)
  end
end

--- Wait a few seconds for line diagnostics, erroring if none arrive.
function helpers.wait_for_line_diagnostics()
  local succeeded, _ = vim.wait(15000, function()
    if progress.is_processing(vim.uri_from_bufnr(0)) then
      return false
    end
    local diagnostics = util.lean_lsp_diagnostics {
      lnum = vim.api.nvim_win_get_cursor(0)[1] - 1,
    }

    -- Lean 4 sends file progress notification too late :-(
    if #diagnostics == 1 then
      local msg = diagnostics[1].message
      if msg:match '^configuring ' then
        return false
      end
      if msg:match '^Foo: ' then
        return false
      end
      if msg:match '^> ' then
        return false
      end
    end

    return #diagnostics > 0
  end)
  assert.message('Waited for line diagnostics but none came.').True(succeeded)
end

function helpers.wait_for_filetype()
  local result, _ = vim.wait(15000, function()
    return vim.bo.filetype == 'lean'
  end)
  assert.message('filetype was never set').is_truthy(result)
end

--- Assert about the current word.
local function has_current_word(_, arguments)
  assert.is.equal(arguments[1], vim.fn.expand '<cword>')
  return true
end
assert:register('assertion', 'current_word', has_current_word)

--- Assert about the current line.
local function has_current_line(_, arguments)
  assert.is.equal(arguments[1], vim.api.nvim_get_current_line())
  return true
end
assert:register('assertion', 'current_line', has_current_line)

--- Assert about the current cursor location.
local function has_current_cursor(_, arguments)
  local window = arguments[1].window or 0
  local got = vim.api.nvim_win_get_cursor(window)

  local column = arguments[1][2] or arguments[1].column or 0
  local expected = { arguments[1][1] or got[1], column }

  assert.are.same(expected, got)
  return true
end
assert:register('assertion', 'current_cursor', has_current_cursor)

--- Assert about the current tabpage.
local function has_current_tabpage(_, arguments)
  assert.is.equal(arguments[1], vim.api.nvim_get_current_tabpage())
  return true
end
assert:register('assertion', 'current_tabpage', has_current_tabpage)

--- Assert about the current window.
local function has_current_window(_, arguments)
  assert.is.equal(arguments[1], vim.api.nvim_get_current_win())
  return true
end
assert:register('assertion', 'current_window', has_current_window)

local function _expected(arguments)
  local expected = arguments[1][1] or arguments[1]
  -- Handle cases where we're indeed checking for a real trailing newline.
  local dedented = util.dedent(expected)
  if dedented ~= expected then
    expected = dedented:gsub('\n$', '')
  end
  return expected
end

--- Assert about the entire buffer contents.
local function has_buf_contents(_, arguments)
  local bufnr = arguments[1].bufnr or 0
  local got = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  assert.is.equal(_expected(arguments), got)
  return true
end
assert:register('assertion', 'contents', has_buf_contents)

--- Assert about the current infoview contents.
local function has_infoview_contents(_, arguments)
  local expected = _expected(arguments)
  local target_infoview = arguments[1].infoview or infoview.get_current_infoview()
  helpers.wait_for_loading_pins(target_infoview)
  local got = table.concat(target_infoview:get_lines(), '\n'):gsub('\n$', '')
  assert.is.equal(expected, got)
  return true
end

--- Assert about the current infoview contents without waiting for the pins to load.
local function has_infoview_contents_nowait(_, arguments)
  local target_infoview = arguments[1].infoview or infoview.get_current_infoview()
  local got = table.concat(target_infoview:get_lines(), '\n')
  assert.are.same(_expected(arguments), got)
  return true
end

local function has_diff_contents(_, arguments)
  local target_infoview = arguments[1].infoview or infoview.get_current_infoview()
  local got = table.concat(target_infoview:get_diff_lines(), '\n')
  assert.are.same(_expected(arguments), got)
  return true
end

assert:register('assertion', 'infoview_contents', has_infoview_contents)
assert:register('assertion', 'infoview_contents_nowait', has_infoview_contents_nowait)
assert:register('assertion', 'diff_contents', has_diff_contents)

local function has_all(_, arguments)
  local text = arguments[1]

  if type(text) == 'table' then
    text = table.concat(text, '\n')
  end
  local expected = arguments[2]
  for _, string in pairs(expected) do
    assert.has_match(string, text, nil, true)
  end
  return true
end

assert:register('assertion', 'has_all', has_all)

--- Assert a tabpage has the given windows open in it.
local function has_open_windows(_, arguments)
  local expected
  if arguments.n == 1 and type(arguments[1]) == 'table' then
    expected = arguments[1]
    expected.n = #expected
  else
    expected = arguments
  end
  local got = vim.api.nvim_tabpage_list_wins(0)
  got.n = #got
  table.sort(expected)
  table.sort(got)
  assert.are.same(expected, got)
  return true
end

assert:register('assertion', 'windows', has_open_windows)

return helpers
