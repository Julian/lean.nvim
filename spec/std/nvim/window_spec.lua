local Buffer = require 'std.nvim.buffer'
local Tab = require 'std.nvim.tab'
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
      local buffer = Buffer.create { listed = false, scratch = true }
      local split = Window:split { buffer = buffer }
      assert.are.same(buffer, split:buffer())
      split:close()
    end)

    it('can be entered when created', function()
      local split = Window:split { enter = true }
      assert.is_true(split:is_current())
      split:close()
    end)
  end)

  describe('is_current', function()
    it('is true for the current window', function()
      local current = Window:current()
      assert.is_true(current:is_current())
    end)

    it('is false for other windows', function()
      local split = Window:split {}
      assert.is_false(split:is_current())
      split:close()
    end)
  end)

  describe('make_current', function()
    it('makes the window the current one', function()
      local split = Window:split {}
      assert.are_not.same(split, Window:current())
      split:make_current()
      assert.are.same(split, Window:current())
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

  describe('tab', function()
    it("returns the window's tabpage", function()
      local initial = Tab:current()
      assert.are.same(initial, Window:current():tab())

      local new = Tab:new()
      assert.are.same(new, Window:current():tab())
    end)
  end)

  describe('buffer', function()
    it('returns the buffer in the window', function()
      local buffer = Buffer:from_bufnr(vim.api.nvim_create_buf(false, true))
      local window = Window:current():split { buffer = buffer }
      assert.are.same(buffer, window:buffer())
      assert.are.equal(buffer.bufnr, vim.api.nvim_win_get_buf(window.id))

      window:close()
    end)

    it('is the current buffer for the current window', function()
      assert.are.same(Buffer:current(), Window:current():buffer())
    end)
  end)

  describe('bufnr', function()
    it('returns the bufnr for the window', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local window = Window:current():split { buffer = Buffer:from_bufnr(bufnr) }
      assert.are.equal(bufnr, window:bufnr())
      window:close()
    end)
  end)

  describe('cursor', function()
    it('tracks the window cursor', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'foo', 'bar' })

      local buffer = Buffer:from_bufnr(bufnr)
      local window = Window:split { buffer = buffer }

      assert.are.same({ 1, 0 }, window:cursor())

      vim.api.nvim_win_set_cursor(window.id, { 1, 2 })
      assert.are.same({ 1, 2 }, window:cursor())

      window:set_cursor { 2, 1 }
      assert.are.same({ 2, 1 }, vim.api.nvim_win_get_cursor(window.id))

      window:close()
      buffer:delete()
    end)

    describe('move_cursor', function()
      local buffer = Buffer.create { listed = false, scratch = true }
      vim.api.nvim_buf_set_lines(buffer.bufnr, 0, -1, false, { 'foo', 'bar' })

      it('moves the cursor firing global CursorMoved', function()
        local count = 0
        local autocmd = vim.api.nvim_create_autocmd('CursorMoved', {
          callback = function()
            count = count + 1
          end,
        })

        local window = Window:split { buffer = buffer }

        assert.are.equal(0, count)
        window:move_cursor { 1, 1 }
        assert.are.same({ 1, 1 }, window:cursor())
        assert.are.equal(1, count)

        window:close()
        vim.api.nvim_del_autocmd(autocmd)
      end)

      it('moves the cursor firing buffer-local CursorMoved', function()
        local count = 0
        local autocmd = vim.api.nvim_create_autocmd('CursorMoved', {
          buffer = buffer.bufnr,
          callback = function()
            count = count + 1
          end,
        })

        local window = Window:split { buffer = buffer }

        assert.are.equal(0, count)
        window:move_cursor { 2, 1 }
        assert.are.same({ 2, 1 }, window:cursor())
        assert.are.equal(1, count)

        window:close()
        vim.api.nvim_del_autocmd(autocmd)
      end)

      it('does not fire autocmds if the cursor does not move', function()
        local count = 0
        local autocmd = vim.api.nvim_create_autocmd('CursorMoved', {
          callback = function()
            count = count + 1
          end,
        })

        local window = Window:split { buffer = buffer }

        window:set_cursor { 2, 1 }
        assert.are.equal(0, count)
        window:move_cursor { 2, 1 }
        assert.are.same({ 2, 1 }, window:cursor())
        assert.are.equal(0, count)

        window:close()
        vim.api.nvim_del_autocmd(autocmd)
      end)

      buffer:delete()
    end)
  end)

  describe('dimensions', function()
    describe('height', function()
      it('can be set and retreived', function()
        local window = Window:split()
        assert.are.same(vim.api.nvim_win_get_height(window.id), window:height())
        window:set_height(10)
        assert.are.same(10, window:height())
        window:close()
      end)
    end)

    describe('width', function()
      it('can be set and retreived', function()
        local window = Window:split()
        assert.are.same(vim.api.nvim_win_get_width(window.id), window:width())
        window:set_width(10)
        assert.are.same(10, window:width())
        window:close()
      end)
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
