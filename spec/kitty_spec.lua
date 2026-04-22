---@brief [[
--- Tests for Kitty graphics protocol support and the overlay system.
---@brief ]]

local Element = require('lean.tui').Element

describe('kitty', function()
  local kitty = require 'kitty'

  describe('cell_size', function()
    it('returns width and height', function()
      local cs = kitty.cell_size()
      assert.is_number(cs.width)
      assert.is_number(cs.height)
      assert.is_true(cs.width > 0)
      assert.is_true(cs.height > 0)
    end)
  end)

  describe('rows_for_height', function()
    it('returns at least 1 row', function()
      assert.are.equal(1, kitty.rows_for_height(1))
    end)

    it('computes correct row count', function()
      local cs = kitty.cell_size()
      assert.are.equal(1, kitty.rows_for_height(cs.height))
      assert.are.equal(2, kitty.rows_for_height(cs.height + 1))
    end)
  end)

  describe('ImageSet', function()
    it('tracks handles', function()
      local set = kitty.ImageSet:new()
      local h1 = set:add('fake-rgba-data', 2, 2)
      local h2 = set:add('fake-rgba-data', 2, 2)
      assert.are.equal(1, h1)
      assert.are.equal(2, h2)
      set:clear()
    end)
  end)

  describe('available', function()
    it('returns a boolean', function()
      -- In headless mode this may be true (from env vars) or false.
      assert.is_boolean(kitty.available())
    end)
  end)
end)

describe('Element overlay', function()
  it('preserves the overlay field through Element:new', function()
    local element = Element:new {
      text = '\n\n',
      overlay = { data = 'fake-rgba-data', width = 2, height = 2, format = 32 },
    }
    assert.is_not_nil(element.overlay)
    assert.are.equal(2, element.overlay.width)
  end)

  it('defaults overlay to nil', function()
    local element = Element:new { text = 'hello' }
    assert.is_nil(element.overlay)
  end)
end)
