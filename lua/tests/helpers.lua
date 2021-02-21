local assert = require('luassert')
local api = vim.api
local helpers = {}


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

--- Create a clean Lean buffer with the given contents.
--
--  Waits for the LSP to be ready before proceeding with a given callback.
--
--  Yes c(lean) may be a double entendre, and no I don't feel bad.
function helpers.clean_buffer(contents, callback)
  -- FIXME: for some reason, even with nvim_buf_delete, I see messages
  --        saying there are existing buffers with the same name when using a
  --        non-incrementing name. And with not setting a name at all, or using
  --        a scratch buffer, the LSP server doesn't start at all.
  _clean_buffer_count = (_clean_buffer_count or 0) + 1

  return function()
    local bufnr = vim.api.nvim_create_buf(false, false)
    api.nvim_buf_set_option(bufnr, 'swapfile', false)
    api.nvim_buf_set_name(bufnr, 'unittest' .. _clean_buffer_count .. '.lean')
    api.nvim_buf_set_option(bufnr, 'filetype', 'lean')

    api.nvim_buf_call(bufnr, function()
      local succeeded, _ = vim.wait(1000, vim.lsp.buf.server_ready)
      assert.message("LSP server was never ready.").True(succeeded)

      api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(contents, '\n'))
      callback()
    end)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

--- Wait a few seconds for line diagnostics, erroring if none arrive.
function helpers.wait_for_line_diagnostics()
  local succeeded, _ = vim.wait(2000, function()
    return not vim.tbl_isempty(vim.lsp.diagnostic.get_line_diagnostics())
  end)
  assert.message("Waited for line diagnostics but none came.").True(succeeded)
end

--- Assert about the entire buffer contents.
local function has_buf_contents(_, arguments)
  local buf = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  return arguments[1] == buf
end

assert:register('assertion', 'contents', has_buf_contents)

return helpers
