---@brief [[
--- Tests for the `tui.modal` primitive.
---@brief ]]

local Buffer = require 'std.nvim.buffer'
local Window = require 'std.nvim.window'

local Element = require('lean.tui').Element
local Modal = require 'tui.modal'

describe('Modal', function()
  it('opens with a fresh scratch buffer when none is provided', function()
    local modal = Modal.open { width = 10, height = 3, row = 0, col = 0 }

    assert.is_true(modal.window:is_valid())
    assert.is_true(modal.buffer:is_valid())

    modal:dismiss()
  end)

  it('uses an existing buffer when one is provided', function()
    local buffer = Buffer.create { scratch = true }
    local modal = Modal.open {
      buffer = buffer,
      width = 10,
      height = 3,
      row = 0,
      col = 0,
    }

    assert.are.equal(buffer.bufnr, modal.buffer.bufnr)

    modal:dismiss()
  end)

  it('focuses the modal by default', function()
    local original = Window:current()
    local modal = Modal.open { width = 10, height = 3, row = 0, col = 0 }

    assert.is_true(modal.window:is_current())
    assert.is_false(original:is_current())

    modal:dismiss()
  end)

  it('does not focus the modal when enter=false', function()
    local original = Window:current()
    local modal = Modal.open {
      width = 10,
      height = 3,
      row = 0,
      col = 0,
      enter = false,
    }

    assert.is_true(original:is_current())
    assert.is_false(modal.window:is_current())

    modal:dismiss()
  end)

  it('opens editor-relative by default', function()
    local modal = Modal.open { width = 5, height = 2, row = 0, col = 0 }

    assert.are.equal('editor', modal.window:config().relative)

    modal:dismiss()
  end)

  it('opens window-relative when given relative_to', function()
    local current = Window:current()
    local modal = Modal.open {
      relative_to = current,
      width = 5,
      height = 2,
      row = 0,
      col = 0,
    }

    local config = modal.window:config()
    assert.are.equal('win', config.relative)
    assert.are.equal(current.id, config.win)

    modal:dismiss()
  end)

  it('is also reachable via Window:modal as a synonym', function()
    local current = Window:current()
    local modal = current:modal { width = 5, height = 2, row = 0, col = 0 }

    local config = modal.window:config()
    assert.are.equal('win', config.relative)
    assert.are.equal(current.id, config.win)

    modal:dismiss()
  end)

  it('does not mutate the caller-supplied opts table', function()
    local opts = {
      width = 5,
      height = 2,
      row = 0,
      col = 0,
      enter = true,
    }
    Modal.open(opts):dismiss()

    assert.are.same({
      width = 5,
      height = 2,
      row = 0,
      col = 0,
      enter = true,
    }, opts)
  end)

  describe(':dismiss', function()
    it('closes the window and force-deletes the buffer', function()
      local modal = Modal.open { width = 5, height = 2, row = 0, col = 0 }
      local window, buffer = modal.window, modal.buffer

      modal:dismiss()

      assert.is_false(window:is_valid())
      assert.is_false(buffer:is_valid())
    end)

    it('is idempotent', function()
      local modal = Modal.open { width = 5, height = 2, row = 0, col = 0 }

      modal:dismiss()
      modal:dismiss() -- second call is a no-op, must not error

      assert.is_false(modal.window:is_valid())
    end)

    it('also tears down an attached renderer and its tooltip', function()
      local modal = Modal.open { width = 10, height = 3, row = 0, col = 0 }
      local element = Element:new { name = 'root', text = 'hello' }
      local renderer = element:renderer { buffer = modal.buffer }
      renderer:render()
      modal:attach(renderer)

      -- Fabricate a tooltip child renderer to verify the cascade closes it.
      -- We don't pop a real tooltip window — the cascade is via the
      -- renderer chain (BufRenderer:close), not via the window.
      local tooltip_buffer = Buffer.create {
        scratch = true,
        options = { bufhidden = 'wipe' },
      }
      local tooltip_element = Element:new { name = 'tip', text = 'tip' }
      renderer.tooltip = tooltip_element:renderer {
        buffer = tooltip_buffer,
        parent = renderer,
      }

      modal:dismiss()

      assert.is_false(modal.window:is_valid())
      assert.is_false(modal.buffer:is_valid())
      assert.is_false(tooltip_buffer:is_valid())
    end)
  end)

  describe(':dismiss_on_leave', function()
    it('dismisses the modal when its window is left', function()
      local original = Window:current()
      local modal = Modal.open {
        relative_to = original,
        width = 5,
        height = 2,
        row = 0,
        col = 0,
      }
      modal:dismiss_on_leave()
      assert.is_true(modal.window:is_current())

      original:make_current()

      assert.is_false(modal.window:is_valid())
      assert.is_false(modal.buffer:is_valid())
    end)
  end)
end)
