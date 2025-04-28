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

  describe('split', function()
    it('splits the window', function()
      assert.is_false(vim.o.splitright)
      local current = Window:current()
      assert.are.same({ 'leaf', current.id }, vim.fn.winlayout())

      local split = current:split {}

      assert.are.same(
        { 'row', { { 'leaf', split.id }, { 'leaf', current.id } } },
        vim.fn.winlayout()
      )

      split:close()
    end)

    it('respects an explicit direction', function()
      assert.is_false(vim.o.splitright)
      local current = Window:current()
      assert.are.same({ 'leaf', current.id }, vim.fn.winlayout())

      local split = current:split { direction = 'right' }

      assert.are.same(
        { 'row', { { 'leaf', current.id }, { 'leaf', split.id } } },
        vim.fn.winlayout()
      )

      split:close()
    end)

    it('respects splitright', function()
      assert.is_false(vim.o.splitright)
      vim.o.splitright = true
      local current = Window:current()
      assert.are.same({ 'leaf', current.id }, vim.fn.winlayout())

      local split = current:split {}

      assert.are.same(
        { 'row', { { 'leaf', current.id }, { 'leaf', split.id } } },
        vim.fn.winlayout()
      )
      vim.o.splitright = false

      split:close()
    end)

    it('splits relative to the current window by default', function()
      assert.is_false(vim.o.splitright)
      local current = Window:current()
      assert.are.same({ 'leaf', current.id }, vim.fn.winlayout())

      local split = Window:split()

      assert.are.same(
        { 'row', { { 'leaf', split.id }, { 'leaf', current.id } } },
        vim.fn.winlayout()
      )

      split:close()
    end)

    it('places a specified buffer', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local split = Window:split { bufnr = bufnr }
      assert.are.same(bufnr, split:bufnr())
      split:close()
    end)
  end)

  describe('close', function()
    it('closes the window', function()
      local window = Window:current():split()
      assert.is_true(vim.api.nvim_win_is_valid(window.id))
      window:close()
      assert.is_false(vim.api.nvim_win_is_valid(window.id))
    end)
  end)

  describe('is valid', function()
    it('indicates whether the window is valid', function()
      local window = Window:current():split()
      assert.is_true(window:is_valid())
      window:close()
      assert.is_false(window:is_valid())
    end)
  end)

  describe('bufnr', function()
    it('returns the bufnr for the window', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local window = Window:current():split { bufnr = bufnr }
      assert.are.equal(bufnr, vim.api.nvim_win_get_buf(window.id))
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

      local window = Window:split { bufnr = bufnr }

      assert.are.same(window:cursor(), { 1, 0 })

      vim.api.nvim_win_set_cursor(window.id, { 1, 2 })
      assert.are.same(window:cursor(), { 1, 2 })

      window:set_cursor { 2, 1 }
      assert.are.same({ 2, 1 }, vim.api.nvim_win_get_cursor(window.id))

      window:close()
    end)
  end)

  describe('call', function()
    it('runs a function inside the window', function()
      local original = Window:current()
      vim.cmd.new()
      local new = Window:current()

      local ran = {}

      original:call(function()
        assert.are.same(original, Window:current())
        table.insert(ran, original)
      end)

      new:call(function()
        assert.are.same(new, Window:current())
        table.insert(ran, new)
      end)

      assert.are.same(ran, { original, new })

      new:close()
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
