local assert = require('luassert')

local api = vim.api
local helpers = {_clean_buffer_counter = 1}


--- Feed some keystrokes into the current buffer, replacing termcodes.
function helpers.feed(text, feed_opts)
  feed_opts = feed_opts or 'n'
  local to_feed = vim.api.nvim_replace_termcodes(text, true, false, true)
  api.nvim_feedkeys(to_feed, feed_opts, true)
end

--- Insert some text into the current buffer.
function helpers.insert(text)
  helpers.feed('i' .. text, 'x')
end

-- Even though we can delete a buffer, so should be able to reuse names,
-- we do this to ensure if a test fails, future ones still get new "files".
local function set_unique_name_so_we_always_have_a_separate_fake_file(bufnr)
  local counter = helpers._clean_buffer_counter
  helpers._clean_buffer_counter = helpers._clean_buffer_counter + 1
  local unique_name = string.format('unittest-%d', counter)
  api.nvim_buf_set_name(bufnr, unique_name)
end

--- Create a clean Lean buffer with the given contents.
--
--  Waits for the LSP to be ready before proceeding with a given callback.
--
--  Yes c(lean) may be a double entendre, and no I don't feel bad.
function helpers.clean_buffer(contents, callback)
  return function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    set_unique_name_so_we_always_have_a_separate_fake_file(bufnr)

    -- FIXME: For now all tests are against Lean 3
    api.nvim_buf_set_option(bufnr, 'filetype', 'lean3')

    api.nvim_buf_call(bufnr, function()

      local succeeded, _ = vim.wait(5000, vim.lsp.buf.server_ready)
      assert.message("LSP server was never ready.").True(succeeded)

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

return helpers
