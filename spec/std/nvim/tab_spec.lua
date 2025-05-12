local Tab = require 'std.nvim.tab'
local Window = require 'std.nvim.window'

describe('Tab', function()
  describe('current', function()
    it('is the current tab', function()
      assert.are.same(Tab:from_id(vim.api.nvim_get_current_tabpage()), Tab:current())
    end)
  end)

  describe('from_id', function()
    it('defaults to current tab', function()
      local tab = Tab:from_id()
      assert.are.same(Tab:current(), tab)
      assert.are.equal(tab.id, vim.api.nvim_get_current_tabpage())
    end)
  end)

  describe('windows', function()
    it('returns the windows in the tab', function()
      local window = Window:current()
      local split = Window:split {}
      local tab = Tab:current()
      assert.are.same({ split, window }, tab:windows())
    end)
  end)

  describe('new', function()
    it('creates a new tab page', function()
      local initial = vim.api.nvim_get_current_tabpage()
      local tab = Tab:current()
      assert.are.same(tab.id, initial)

      local new = Tab:new {}
      local id = vim.api.nvim_get_current_tabpage()
      assert.are_not.same(id, initial)

      assert.are.same(new.id, id)
      assert.are.same(Tab:current(), new)
    end)
  end)
end)
