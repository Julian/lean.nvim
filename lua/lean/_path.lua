---@mod lean._path Path utilities

---@brief [[
--- Path utilities for compatibility across Neovim versions.
---@brief ]]

local path = {}

---Get the directory name of a path.
---@param p string The path
---@return string The directory name
function path.dirname(p)
  if vim.fs and vim.fs.dirname then
    return vim.fs.dirname(p)
  else
    return vim.fn.fnamemodify(p, ':h')
  end
end

---Join path components.
---@param ... string Path components to join
---@return string The joined path
function path.joinpath(...)
  if vim.fs and vim.fs.joinpath then
    return vim.fs.joinpath(...)
  else
    local parts = {...}
    return table.concat(parts, '/')
  end
end

return path