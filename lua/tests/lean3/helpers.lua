local dedent = require('lean._util').dedent
local helpers = { _clean_buffer_counter = 1 }

-- Even though we can delete a buffer, so should be able to reuse names,
-- we do this to ensure if a test fails, future ones still get new "files".
local function set_unique_name_so_we_always_have_a_separate_fake_file(bufnr)
  local counter = helpers._clean_buffer_counter
  helpers._clean_buffer_counter = helpers._clean_buffer_counter + 1
  local unique_name = string.format('unittest-%d.lean', counter)
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
    lines = vim.split(dedent(contents:gsub('^\n', '')):gsub('\n$', ''), '\n')
  end

  return function()
    local bufnr = vim.api.nvim_create_buf(false, false)
    set_unique_name_so_we_always_have_a_separate_fake_file(bufnr)
    -- apparently necessary to trigger BufWinEnter
    vim.api.nvim_set_current_buf(bufnr)
    vim.bo.bufhidden = 'hide'
    vim.bo.swapfile = false
    vim.bo.filetype = 'lean3'

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_call(bufnr, function()
      callback { source_file = { bufnr = bufnr } }
    end)
  end
end

return helpers
