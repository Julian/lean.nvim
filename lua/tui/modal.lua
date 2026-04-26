local Buffer = require 'std.nvim.buffer'
local Window = require 'std.nvim.window'

---@class ModalOpts
---@field buffer? Buffer  buffer to display (default: a fresh scratch buffer)
---@field enter? boolean  focus the modal (default: `true`)
---@field relative_to? Window  open window-relative to this Window
---                            (default: open editor-relative)

---A floating window with an attached buffer whose lifecycles are tied
---together. Optionally bundles a `BufRenderer` so dismissing the modal also
---closes any tooltip the renderer has open.
---
---Reach for this anywhere a floating popup is paired with a scratch buffer.
---Going through `Modal:dismiss()` ensures all three pieces (window, buffer,
---and any tooltip chain on an attached renderer) are torn down together;
---using `Window:force_close` directly will leak the buffer and any tooltip
---floats.
---@class Modal
---@field window Window the floating window
---@field buffer Buffer the buffer being shown
---@field private __renderer? BufRenderer
---@field private __dismissed boolean
local Modal = {}
Modal.__index = Modal

---Open a floating window backed by a buffer.
---
---Defaults to editor-relative. Pass `relative_to = some_window` to anchor
---the modal to a specific window instead.
---
---`buffer` defaults to a fresh scratch buffer; `enter` defaults to `true`.
---@param opts? ModalOpts
---@return Modal
function Modal.open(opts)
  opts = vim.tbl_extend('keep', opts or {}, { enter = true })
  opts.buffer = opts.buffer or Buffer.create { listed = false, scratch = true }

  local target = opts.relative_to
  opts.relative_to = nil
  local window = target and target:float(opts) or Window.editor_float(opts)

  return setmetatable({
    window = window,
    buffer = opts.buffer,
    __dismissed = false,
  }, Modal)
end

---Attach a `BufRenderer` so `:dismiss` also tears it down (closing any
---open tooltip).
---@param renderer BufRenderer
---@return Modal self
function Modal:attach(renderer)
  self.__renderer = renderer
  return self
end

---Dismiss this modal whenever its window is left.
---
---The buffer-local autocmd is automatically cleaned up by Neovim when the
---buffer is deleted (i.e. when the modal is dismissed), so no separate
---teardown is needed.
---@return Modal self
function Modal:dismiss_on_leave()
  self.buffer:create_autocmd('WinLeave', {
    callback = function()
      self:dismiss()
    end,
  })
  return self
end

---Tear down the modal: close the attached renderer (and any tooltip it has
---open), close the window, and force-delete the buffer. Idempotent.
function Modal:dismiss()
  if self.__dismissed then
    return
  end
  self.__dismissed = true

  if self.__renderer then
    self.__renderer:close()
  elseif self.buffer:is_loaded() then
    self.buffer:force_delete()
  end
  if self.window:is_valid() then
    self.window:force_close()
  end
end

return Modal
