local Element = require('lean.tui').Element
local graphic = require 'tui.graphic'
local kitty = require 'kitty'

describe('tui.graphic', function()
  it('returns the graphical element when kitty is available', function()
    if not kitty.available() then
      pending 'kitty is not available in this terminal'
      return
    end
    local graphical_called = false
    local fallback_called = false
    local el = graphic.render(function()
      graphical_called = true
      return Element.text 'graphic'
    end, function()
      fallback_called = true
      return Element.text 'fallback'
    end)
    assert.is.equal('graphic', el:to_string())
    assert.is_true(graphical_called)
    assert.is_false(fallback_called)
  end)

  it('returns the fallback when kitty is unavailable', function()
    if kitty.available() then
      pending 'kitty is available in this terminal'
      return
    end
    local graphical_called = false
    local el = graphic.render(function()
      graphical_called = true
      return Element.text 'graphic'
    end, function()
      return Element.text 'fallback'
    end)
    assert.is.equal('fallback', el:to_string())
    assert.is_false(graphical_called)
  end)

  it('falls back when the graphical function returns nil', function()
    if not kitty.available() then
      pending 'kitty is not available in this terminal'
      return
    end
    local el = graphic.render(function()
      return nil
    end, function()
      return Element.text 'fallback'
    end)
    assert.is.equal('fallback', el:to_string())
  end)
end)
