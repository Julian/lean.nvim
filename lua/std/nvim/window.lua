---A Neovim window.
---@class Window
---@field id integer The window ID
local Window = {}
Window.__index = Window

---Bind to a neovim Window.
---@param id? integer Window ID, defaulting to the current window
---@return Window
function Window:from_id(id)
  return setmetatable({ id = id or vim.api.nvim_get_current_win() }, self)
end

---Bind to the current window.
function Window:current()
  return self:from_id(vim.api.nvim_get_current_win())
end

---Return the buffer number of the window.
---@return integer bufnr
function Window:bufnr()
  return vim.api.nvim_win_get_buf(self.id)
end

---Return the window's current cursor position.
---
---(1, 0)-indexed, like `nvim_win_get_cursor()`.
---@return { [1]: integer, [2]: integer } pos
function Window:cursor()
  return vim.api.nvim_win_get_cursor(self.id)
end

---Set the window's current cursor position.
---
---(1, 0)-indexed, like `nvim_win_set_cursor()`.
---@param pos { [1]: integer, [2]: integer } the new cursor position
function Window:set_cursor(pos)
  vim.api.nvim_win_set_cursor(self.id, pos)
end

---Close the window.
function Window:close()
  vim.api.nvim_win_close(self.id, false)
end

---Get the contents of the remainder of the line with the window's cursor.
---@return string contents text from cursor position to the end of line
function Window:rest_of_cursor_line()
  local row, col = unpack(self:cursor())
  local line = vim.api.nvim_buf_get_lines(self:bufnr(), row - 1, row, true)[1]
  return line:sub(col + 1)
end

return Window
