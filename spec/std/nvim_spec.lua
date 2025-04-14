local nvim = require 'std.nvim'

describe('Window', function()
  it('defaults to current window', function()
    assert.are.same(nvim.Window(vim.api.nvim_get_current_win()), nvim.Window())
  end)

  describe('rest_of_cursor_line', function()
    it('gets the rest of the line at cursor position', function()
      vim.cmd.new()
      local win = vim.api.nvim_get_current_win()

      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'Hello, world!' })
      vim.api.nvim_win_set_cursor(win, { 1, #'Hello,' })

      local window = nvim.Window(win)

      assert.equals(' world!', window:rest_of_cursor_line())

      vim.cmd.close()
    end)
  end)
end)
