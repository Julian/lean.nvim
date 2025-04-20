local Window = require 'std.nvim.window'

describe('Window', function()
  describe('current', function()
    it('is the current window', function()
      assert.are.same(Window:from_id(vim.api.nvim_get_current_win()), Window:current())
    end)
  end)

  describe('from_id', function()
    it('defaults to current window', function()
      assert.are.same(Window:current(), Window:from_id())
    end)
  end)

  describe('close', function()
    it('closes the window', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local id = vim.api.nvim_open_win(bufnr, false, { split = 'right' })
      local window = Window:from_id(id)

      assert.is_true(vim.api.nvim_win_is_valid(id))
      window:close()
      assert.is_false(vim.api.nvim_win_is_valid(id))
    end)
  end)

  describe('bufnr', function()
    it('returns the bufnr for the window', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local id = vim.api.nvim_open_win(bufnr, false, { split = 'right' })
      local window = Window:from_id(id)

      assert.are.equal(bufnr, window:bufnr())

      window:close()
    end)

    it('is the current buffer for the current window', function()
      assert.are.equal(vim.api.nvim_get_current_buf(), Window:current():bufnr())
    end)
  end)

  describe('cursor', function()
    it('tracks the window cursor', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'foo', 'bar' })

      local id = vim.api.nvim_open_win(bufnr, false, { split = 'right' })
      local window = Window:from_id(id)

      assert.are.same(window:cursor(), { 1, 0 })

      vim.api.nvim_win_set_cursor(id, { 1, 2 })
      assert.are.same(window:cursor(), { 1, 2 })

      window:set_cursor { 2, 1 }
      assert.are.same({ 2, 1 }, vim.api.nvim_win_get_cursor(id))

      window:close()
    end)
  end)

  describe('rest_of_cursor_line', function()
    it('gets the rest of the line at cursor position', function()
      vim.cmd.new()
      local window = Window:current()

      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'Hello, world!' })
      window:set_cursor { 1, #'Hello,' }

      assert.are.equal(' world!', window:rest_of_cursor_line())

      window:close()
    end)
  end)
end)
