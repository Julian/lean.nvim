---A Neovim buffer.
---@class Buffer
---@field bufnr integer The buffer number
---@field b table<string, any> Buffer-local variables (alias for vim.b[bufnr])
---@field o table<string, any> Buffer-local options (alias for vim.bo[bufnr])
local Buffer = {}
Buffer.__index = function(self, key)
  if key == 'o' then
    return vim.bo[self.bufnr]
  elseif key == 'b' then
    return vim.b[self.bufnr]
  end
  return Buffer[key]
end

---Bind to the current buffer.
---@return Buffer
function Buffer:current()
  return self:from_bufnr(vim.api.nvim_get_current_buf())
end

---Bind to a Neovim buffer.
---@param bufnr? integer buffer number, defaulting to the current one
---@return Buffer
function Buffer:from_bufnr(bufnr)
  return setmetatable({ bufnr = bufnr or vim.api.nvim_get_current_buf() }, self)
end

---Bind to a Neovim buffer from its URI.
---@param uri string the buffer's URI
---@return Buffer
function Buffer:from_uri(uri)
  return self:from_bufnr(vim.uri_to_bufnr(uri))
end

---@class CreateBufferOpts
---@field name? string the name of the new buffer
---@field options? table<string, any> a table of buffer options
---@field listed? boolean see :h nvim_create_buf (default true)
---@field scratch? boolean see :h nvim_create_buf (default false)

---Create a new buffer.
---@param opts? CreateBufferOpts options for the new buffer
---@return Buffer
function Buffer.create(opts)
  opts = opts or {}
  local listed = opts.listed
  if listed == nil then
    listed = true
  end
  local scratch = opts.scratch
  if scratch == nil then
    scratch = false
  end
  local bufnr = vim.api.nvim_create_buf(listed, scratch)
  for option, value in pairs(opts.options or {}) do
    vim.bo[bufnr][option] = value
  end
  if opts.name ~= nil then
    vim.api.nvim_buf_set_name(bufnr, opts.name)
  end
  return Buffer:from_bufnr(bufnr)
end

---The buffer's name.
---@return string name
function Buffer:name()
  return vim.api.nvim_buf_get_name(self.bufnr)
end

---The buffer's URI.
---@return string uri
function Buffer:uri()
  return vim.uri_from_bufnr(self.bufnr)
end

---Check if the buffer is loaded.
---@return boolean
function Buffer:is_loaded()
  return vim.api.nvim_buf_is_loaded(self.bufnr)
end

---Check if the buffer is valid.
---@return boolean
function Buffer:is_valid()
  return vim.api.nvim_buf_is_valid(self.bufnr)
end

---Delete the buffer.
function Buffer:delete()
  vim.api.nvim_buf_delete(self.bufnr, {})
end

---Forcibly delete the buffer.
function Buffer:force_delete()
  vim.api.nvim_buf_delete(self.bufnr, { force = true })
end

---Make the buffer be the current one.
function Buffer:make_current()
  vim.api.nvim_set_current_buf(self.bufnr)
end

---The buffer's line count.
function Buffer:line_count()
  return vim.api.nvim_buf_line_count(self.bufnr)
end

---Get lines from the buffer.
---
---Zero-indexed, like nvim_buf_get_lines().
---
---@param start? integer start line (default 0)
---@param end_? integer end line (default -1, meaning the end of the buffer)
function Buffer:lines(start, end_)
  return vim.api.nvim_buf_get_lines(self.bufnr, start or 0, end_ or -1, true)
end

---Get a specific line from the buffer.
---@param line integer the line number (0-indexed)
---@param strict_indexing? boolean Whether out-of-bounds should be an error
function Buffer:line(line, strict_indexing)
  if strict_indexing == nil then
    strict_indexing = true
  end
  return vim.api.nvim_buf_get_lines(self.bufnr, line, line + 1, strict_indexing)[1]
end

---Set lines in the buffer.
---
---See :h nvim_buf_set_lines for details.
---
---@param replacement string[]
---@param start? integer
---@param end_? integer
---@param strict_indexing? boolean defaults to true
function Buffer:set_lines(replacement, start, end_, strict_indexing)
  vim.api.nvim_buf_set_lines(
    self.bufnr,
    start or 0,
    end_ or -1,
    strict_indexing == nil and true or strict_indexing,
    replacement
  )
end

---Attach a callback to a buffer.
---
---See :h nvim_buf_attach for details.
---
---@param opts table See :h nvim_buf_attach
function Buffer:attach(opts)
  vim.api.nvim_buf_attach(self.bufnr, false, opts)
end

---Get extmarks from the buffer.
---
---See :h nvim_buf_get_extmarks for details.
---
---@param ns_id? integer
---@param start? integer| { [1]: integer, [2]: integer }
---@param end_? integer| { [1]: integer, [2]: integer }
---@param opts? table
function Buffer:extmarks(ns_id, start, end_, opts)
  return vim.api.nvim_buf_get_extmarks(self.bufnr, ns_id or -1, start or 0, end_ or -1, opts or {})
end

---Set an extmark in the buffer.
---
---See :h nvim_buf_set_extmark for details.
---
---@param ns_id integer
---@param line integer
---@param col integer
---@param opts table
---@return integer
function Buffer:set_extmark(ns_id, line, col, opts)
  return vim.api.nvim_buf_set_extmark(self.bufnr, ns_id, line, col, opts)
end

---Delete an extmark in the buffer.
---
---See :h nvim_buf_del_extmark for details.
---
---@param ns_id integer
---@param id integer the extmark ID
function Buffer:del_extmark(ns_id, id)
  local ok = vim.api.nvim_buf_del_extmark(self.bufnr, ns_id, id)
  if not ok then
    local message = 'extmark %d does not exist in namespace %d'
    error(message:format(id, ns_id))
  end
end

---Clear a namespace in the buffer.
---
---See :h nvim_buf_clear_namespace for details.
---
---@param ns_id integer
---@param start_line? integer
---@param end_line? integer
function Buffer:clear_namespace(ns_id, start_line, end_line)
  vim.api.nvim_buf_clear_namespace(self.bufnr, ns_id or -1, start_line or 0, end_line or -1)
end

---Create an autocmd for this buffer.
---
---See nvim_create_autocmd() for details.
---
---@param event string|string[] The event or events.
---@param opts table The autocmd options (callback, etc). Buffer will be set automatically.
---@return integer autocmd_id
function Buffer:create_autocmd(event, opts)
  opts = vim.tbl_extend('error', { buffer = self.bufnr }, opts)
  return vim.api.nvim_create_autocmd(event, opts)
end

return Buffer
