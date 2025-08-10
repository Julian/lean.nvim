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

  describe('uri', function()
    it('returns the buffer URI', function()
      local buffer = Buffer.create { name = '/tmp/test/uri_buf' }
      local expected_uri = vim.uri_from_bufnr(buffer.bufnr)
      assert.are.same(expected_uri, buffer:uri())
      buffer:force_delete()
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

  describe('set_lines', function()
    it('sets all lines when given no other arguments', function()
      local buffer = Buffer.create {}
      buffer:set_lines { 'foo', 'bar', 'baz', 'quux' }
      assert.are.same({ 'foo', 'bar', 'baz', 'quux' }, buffer:lines())
      buffer:force_delete()
    end)

    it('sets lines from start until end', function()
      local buffer = Buffer.create {}
      buffer:set_lines { 'foo', 'bar', 'baz', 'quux' }
      buffer:set_lines({ 'a', 'b' }, 1, 3, false)
      assert.are.same({ 'foo', 'a', 'b', 'quux' }, buffer:lines())
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

  describe('make_current', function()
    it('makes a buffer the current buffer', function()
      local window = Window:current()
      local buffer = Buffer.create {}
      assert.is_not.same(buffer, window:buffer())
      buffer:make_current()
      assert.is.same(buffer, window:buffer())
      assert.is.equal(vim.api.nvim_get_current_buf(), buffer.bufnr)
    end)
  end)

  describe('create_autocmd', function()
    it('creates an autocmd for the buffer', function()
      local original = Buffer:current()

      local buffer = Buffer.create {}
      local triggered = false
      buffer:create_autocmd('CursorHoldI', {
        callback = function()
          triggered = true
        end,
      })

      vim.api.nvim_exec_autocmds('CursorHoldI', { buffer = original.bufnr })
      assert.is_false(triggered)

      vim.api.nvim_exec_autocmds('CursorHoldI', { buffer = buffer.bufnr })
      assert.is_true(triggered)

      buffer:force_delete()
    end)
  end)

  describe('b', function()
    it('returns the buffer-local variables', function()
      local buffer = Buffer.create {}
      assert.is_nil(buffer.b.foo)
      buffer.b.foo = 37
      assert.is.equal(37, buffer.b.foo)
      buffer:force_delete()
    end)
  end)

  describe('o', function()
    it('returns the buffer options table', function()
      local buffer = Buffer.create { options = { buftype = 'nofile' } }
      assert.are.same('nofile', buffer.o.buftype)
      buffer.o.buftype = 'nowrite'
      assert.are.same('nowrite', vim.bo[buffer.bufnr].buftype)
      buffer:force_delete()
    end)
  end)

  describe('attach', function()
    it('attaches an on_lines callback to the buffer', function()
      local buffer = Buffer.create {}
      local triggered = false
      buffer:attach {
        on_lines = function()
          triggered = true
        end,
      }
      buffer:set_lines { 'foo' }
      assert.is_true(triggered)
      buffer:force_delete()
    end)
  end)

  describe('extmarks', function()
    it('gets extmarks in the buffer', function()
      local buffer = Buffer.create {}
      local ns = vim.api.nvim_create_namespace ''
      local another = vim.api.nvim_create_namespace ''
      local one = vim.api.nvim_buf_set_extmark(buffer.bufnr, ns, 0, 0, {})
      local two = vim.api.nvim_buf_set_extmark(buffer.bufnr, another, 0, 0, {})

      assert.are.same({ { one, 0, 0 }, { two, 0, 0 } }, buffer:extmarks())

      buffer:force_delete()
    end)

    it('filters by namespace ID', function()
      local buffer = Buffer.create {}
      local ns = vim.api.nvim_create_namespace ''
      local another = vim.api.nvim_create_namespace ''
      local one = vim.api.nvim_buf_set_extmark(buffer.bufnr, ns, 0, 0, {})
      vim.api.nvim_buf_set_extmark(buffer.bufnr, another, 0, 0, {})

      assert.are.same({ { one, 0, 0 } }, buffer:extmarks(ns))

      buffer:force_delete()
    end)

    it('only returns marks within the given range', function()
      local buffer = Buffer.create {}
      buffer:set_lines { 'line 1', 'line 2', 'line 3' }
      local ns = vim.api.nvim_create_namespace ''
      vim.api.nvim_buf_set_extmark(buffer.bufnr, ns, 0, 0, {})
      local two = vim.api.nvim_buf_set_extmark(buffer.bufnr, ns, 1, 0, {})
      local three = vim.api.nvim_buf_set_extmark(buffer.bufnr, ns, 1, 2, {})
      local four = vim.api.nvim_buf_set_extmark(buffer.bufnr, ns, 1, 4, {})
      vim.api.nvim_buf_set_extmark(buffer.bufnr, ns, 2, 0, {})
      assert.are.same(
        { { two, 1, 0 }, { three, 1, 2 }, { four, 1, 4 } },
        buffer:extmarks(ns, two, four)
      )

      buffer:force_delete()
    end)
  end)

  describe('set_extmark', function()
    it('sets an extmark in the buffer', function()
      local buffer = Buffer.create {}
      local ns = vim.api.nvim_create_namespace ''
      local id = buffer:set_extmark(ns, 0, 0, {})
      assert.is_number(id)
      local marks = buffer:extmarks(ns)
      assert.are.same({ { id, 0, 0 } }, marks)
      buffer:force_delete()
    end)
  end)

  describe('del_extmark', function()
    it('deletes an existing extmark', function()
      local buffer = Buffer.create {}
      local ns = vim.api.nvim_create_namespace ''
      local id = buffer:set_extmark(ns, 0, 0, {})
      assert.are.same({ { id, 0, 0 } }, buffer:extmarks(ns))
      buffer:del_extmark(ns, id)
      assert.are.same({}, buffer:extmarks(ns))
      buffer:force_delete()
    end)

    it('errors when deleting a non-existent extmark', function()
      local buffer = Buffer.create {}
      local ns = vim.api.nvim_create_namespace ''
      assert.has_error(function()
        buffer:del_extmark(ns, 999)
      end, 'extmark 999 does not exist in namespace ' .. ns)
      buffer:force_delete()
    end)
  end)
end)
