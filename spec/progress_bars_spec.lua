local Buffer = require 'std.nvim.buffer'

local helpers = require 'spec.helpers'
local progress = require 'lean.progress'
local progress_bars = require 'lean.progress_bars'

local PROGRESS_NS = vim.api.nvim_create_namespace 'lean.progress'

---Return whether there are any progress bar signs in the given buffer.
---@param bufnr? integer defaults to the current buffer
local function has_progress_bar_signs(bufnr)
  return #vim.api.nvim_buf_get_extmarks(bufnr or 0, PROGRESS_NS, 0, -1, {}) > 0
end

describe('progress bars', function()
  it(
    'are cleared when the LSP server dies',
    helpers.clean_buffer('#eval IO.sleep 5000', function()
      helpers.wait:for_progress_bars()

      -- Kill the LSP while signs are visible.
      for _, client in ipairs(vim.lsp.get_clients { bufnr = 0 }) do
        client:stop()
      end
      local succeeded = vim.wait(5000, function()
        return vim.tbl_isempty(vim.lsp.get_clients { bufnr = 0 })
      end)
      assert.message("Couldn't kill the LSP!").is_true(succeeded)

      assert.message('progress bar signs were not cleaned up').is_false(has_progress_bar_signs())
    end)
  )

  -- The Lean server reports progress with LSP end-exclusive ranges and on a
  -- 100ms-deferred timer, so the buffer can shrink between notification and
  -- update.  Either way we must not raise "Invalid 'line': out of range".
  it('clamps ranges that extend past the end of the buffer', function()
    local buffer = Buffer.create {
      listed = false,
      name = 'progress_bars_spec_clamp.lean',
      options = { swapfile = false },
    }
    buffer:set_lines { 'line 1', 'line 2', 'line 3' }
    local uri = buffer:uri()

    progress.proc_infos[uri] = {
      {
        range = {
          start = { line = 0, character = 0 },
          ['end'] = { line = 999, character = 0 },
        },
      },
    }

    progress_bars.update { textDocument = { uri = uri } }
    helpers.wait:for_progress_bars(buffer.bufnr)

    local marks =
      vim.api.nvim_buf_get_extmarks(buffer.bufnr, PROGRESS_NS, 0, -1, { details = true })
    assert.is.equal(3, #marks)
    for _, mark in ipairs(marks) do
      assert.is_true(mark[2] <= 2)
    end

    progress_bars.clear(buffer.bufnr)
    progress.proc_infos[uri] = nil
  end)
end)
