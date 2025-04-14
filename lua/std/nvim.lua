local nvim = {}

---A Neovim window.
---@class Window
---@field id integer The window ID
local Window = {}
Window.__index = Window

---Bind to a neovim Window.
---@param id? integer Window ID, defaulting to the current window
---@return Window
function nvim.Window(id)
  return setmetatable({ id = id or vim.api.nvim_get_current_win() }, Window)
end

---Get the contents of the remainder of the line with the window's cursor.
---@return string contents text from cursor position to the end of line
function Window:rest_of_cursor_line()
  local row, col = unpack(vim.api.nvim_win_get_cursor(self.id))
  local bufnr = vim.api.nvim_win_get_buf(self.id)
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, true)[1]
  return line:sub(col + 1)
end

return nvim
