local Buffer = require 'std.nvim.buffer'
local Window = require 'std.nvim.window'

describe('Buffer', function()
  describe('current', function()
    it('is the current buffer', function()
      assert.are.same(Buffer:from_bufnr(vim.api.nvim_get_current_buf()), Buffer:current())
    end)
  end)

  describe('from_bufnr', function()
    it('defaults to current buffer', function()
      assert.are.same(Buffer:current(), Buffer:from_bufnr())
    end)
  end)

  describe('from_uri', function()
    it('binds to buffer by file:// URI', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, '/tmp/from/uri/buf')
      local uri = vim.uri_from_bufnr(bufnr)
      local buffer = Buffer:from_uri(uri)
      assert.are.same(Buffer:from_bufnr(bufnr), buffer)
    end)
  end)

  describe('create', function()
    it('creates a new buffer', function()
      local before = vim.api.nvim_list_bufs()
      local buffer = Buffer.create {}
      table.insert(before, buffer.bufnr)
      assert.is.same(before, vim.api.nvim_list_bufs())
      assert.is_true(vim.bo[buffer.bufnr].buflisted)
    end)

    it('can set the new buffer name', function()
      local buffer = Buffer.create { name = '/tmp/test/buf' }
      assert.is.same('/tmp/test/buf', buffer:name())
    end)

    it('can set listed and scratch', function()
      local buffer = Buffer.create { listed = false, scratch = true }
      assert.is_false(vim.bo[buffer.bufnr].buflisted)
      assert.is.same('nofile', vim.bo[buffer.bufnr].buftype)
    end)

    it('can set additional options', function()
      local buffer = Buffer.create { options = { buftype = 'prompt' } }
      assert.is.same('prompt', vim.bo[buffer.bufnr].buftype)
    end)
  end)

  describe('name', function()
    it('returns the buffer name', function()
      local buffer = Buffer:from_bufnr(vim.api.nvim_create_buf(false, true))
      vim.api.nvim_buf_set_name(buffer.bufnr, '/tmp/foo/bar')
      assert.are.same('/tmp/foo/bar', buffer:name())
    end)
  end)

  describe('bufnr', function()
    it('is the bufnr for the buffer', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local buffer = Buffer:from_bufnr(bufnr)
      assert.are.equal(bufnr, buffer.bufnr)
    end)

    it('is the current bufnr for the current buffer', function()
      assert.are.equal(vim.api.nvim_get_current_buf(), Buffer:current().bufnr)
    end)
  end)

  describe('force_delete', function()
    it('forcibly deletes the buffer', function()
      local buffer = Buffer.create {}
      vim.api.nvim_buf_set_lines(buffer.bufnr, 0, -1, false, { 'unsaved' })
      local window = Window:split { buffer = buffer }

      -- this still spews nonsense to stderr in the test run
      assert.has_error(function()
        buffer:delete()
      end, 'Failed to unload buffer.')

      assert.is_true(buffer:is_valid())
      buffer:force_delete()
      assert.is_false(buffer:is_valid())
      assert.is_false(window:is_valid()) -- because its buffer is gone
    end)
  end)

  describe('is_valid', function()
    it('returns true for valid buffers and false for invalid ones', function()
      local buffer = Buffer.create {}
      assert.is_true(buffer:is_valid())
      buffer:delete()
      assert.is_false(buffer:is_valid())
    end)
  end)

  describe('is_loaded', function()
    it('returns true for loaded buffers and false for unloaded ones', function()
      local buffer = Buffer.create {}
      assert.is_true(buffer:is_loaded())
      buffer:delete()
      assert.is_false(buffer:is_loaded())
    end)
  end)

  describe('line_count', function()
    it('returns the line count', function()
      local buffer = Buffer.create {}
      assert.are.equal(1, buffer:line_count())

      vim.api.nvim_buf_set_lines(buffer.bufnr, 0, -1, false, { 'foo', 'bar', 'baz' })
      assert.are.equal(3, buffer:line_count())

      buffer:force_delete()
    end)
  end)

  describe('lines', function()
    it('returns lines from start until end', function()
      local buffer = Buffer.create {}
      vim.api.nvim_buf_set_lines(buffer.bufnr, 0, -1, false, { 'foo', 'bar', 'baz', 'quux' })
      assert.are.same({ 'bar', 'baz' }, buffer:lines(1, 3))
      buffer:force_delete()
    end)

    it('allows an implicit end', function()
      local buffer = Buffer.create {}
      vim.api.nvim_buf_set_lines(buffer.bufnr, 0, -1, false, { 'foo', 'bar', 'baz', 'quux' })
      assert.are.same({ 'baz', 'quux' }, buffer:lines(2))
      buffer:force_delete()
    end)

    it('returns all lines when given no arguments', function()
      local buffer = Buffer.create {}
      vim.api.nvim_buf_set_lines(buffer.bufnr, 0, -1, false, { 'foo', 'bar', 'baz' })
      assert.are.same({ 'foo', 'bar', 'baz' }, buffer:lines())
      buffer:force_delete()
    end)
  end)

  describe('line', function()
    it('returns the given line', function()
      local buffer = Buffer.create {}
      vim.api.nvim_buf_set_lines(buffer.bufnr, 0, -1, false, { 'foo', 'bar', 'baz', 'quux' })
      assert.are.same('bar', buffer:line(1))
      buffer:force_delete()
    end)
  end)
end)
