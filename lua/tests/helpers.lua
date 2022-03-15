local assert = require('luassert')

local dedent = require('lean._util').dedent
local fixtures = require('tests.fixtures')
local infoview = require('lean.infoview')
local progress = require('lean.progress')

local helpers = {_clean_buffer_counter = 1}

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
    if namespace:match('^lean.') then
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
---@param opts table
---@field window integer @the window handle. Defaults to the current window.
---@field to table @the new cursor position (1-row indexed, as per nvim_win_set_cursor)
function helpers.move_cursor(opts)
  vim.api.nvim_win_set_cursor(opts.window or 0, opts.to)
  vim.cmd[[doautocmd CursorMoved]]
end

function helpers.wait_for_ready_lsp()
  local succeeded, _ = vim.wait(5000, vim.lsp.buf.server_ready)
  assert.message('LSP server was never ready.').True(succeeded)
end

--- Wait until a single line in the infoview matches the given contents.
function helpers.wait_for_infoview_contents(contents)
  local current_infoview = infoview.get_current_infoview()
  local succeeded, _ = vim.wait(5000, function()
    if table.concat(current_infoview:get_lines(), "\n"):match(contents) then
      return true
    end
  end)
  local message = string.format(
    "Infoview never contained %q. Last contents were %q.",
    contents,
    table.concat(current_infoview:get_lines(), '\n')
  )
  assert.message(message).True(succeeded)
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
local function set_unique_name_so_we_always_have_a_separate_fake_file(bufnr, ft)
  local counter = helpers._clean_buffer_counter
  helpers._clean_buffer_counter = helpers._clean_buffer_counter + 1
  local unique_name =
    ft == 'lean3' and string.format('unittest-%d.lean', counter)
                   or string.format('%s/unittest-%d.lean', fixtures.lean_project.path, counter)
  vim.api.nvim_buf_set_name(bufnr, unique_name)
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

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(contents, '\n'))
    vim.api.nvim_buf_call(bufnr, function() callback{ source_file = { bufnr = bufnr } } end)
  end
end

--- Wait a few seconds for line diagnostics, erroring if none arrive.
function helpers.wait_for_line_diagnostics()
  local succeeded, _ = vim.wait(5000, function()
    if progress.is_processing(vim.uri_from_bufnr(0)) then return false end
    local diags = vim.diagnostic.get(0, {lnum = vim.api.nvim_win_get_cursor(0)[1] - 1})

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
  local result, _ = vim.wait(10000, require"lean".is_lean_buffer)
  assert.message("filetype was never set").is_truthy(result)
end

--- Assert about the entire buffer contents.
local function has_buf_contents(_, arguments)
  local expected = arguments[1][1] or arguments[1]
  local bufnr = arguments[1].bufnr or 0
  local got = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  assert.equal(expected, got)
  return true
end

assert:register('assertion', 'contents', has_buf_contents)

--- Assert about the current infoview contents.
local function has_infoview_contents(_, arguments)
  local expected = dedent(arguments[1][1] or arguments[1])
  local target_infoview = arguments[1].infoview or infoview.get_current_infoview()
  local got = table.concat(target_infoview:get_lines(), '\n')
  assert.are.same(expected, got)
  return true
end

assert:register('assertion', 'infoview_contents', has_infoview_contents)

local function has_all(_, arguments)
  local text = arguments[1]

  if type(text) == "table" then text = table.concat(text, "\n") end
  local expected = arguments[2]
  for _, string in pairs(expected) do
    assert.has_match(string, text, nil, true)
  end
  return true
end

assert:register('assertion', 'has_all', has_all)

--- Assert a tabpage has the given windows open in it.
local function has_open_windows(_, arguments)
  local expected, count
  if arguments.n == 1 and type(arguments[1]) == 'table' then
    expected = arguments[1]
    count = #expected
  else
    count = arguments.n
    arguments.n = nil
    expected = arguments
  end
  local got = vim.api.nvim_tabpage_list_wins(0)
  table.sort(expected)
  table.sort(got)
  assert.are.same(expected, got)
  local wrong_count = 'Expected %d != %d windows'
  assert.message(wrong_count:format(count, #got)).is.equal(count, #got)
  return true
end

assert:register('assertion', 'windows', has_open_windows)

return helpers
