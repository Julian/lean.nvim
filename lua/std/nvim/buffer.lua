---A Neovim buffer.
---@class Buffer
---@field bufnr integer The buffer number
local Buffer = {}
Buffer.__index = Buffer

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
function Buffer:line(line)
  return vim.api.nvim_buf_get_lines(self.bufnr, line, line + 1, true)[1]
end

return Buffer
