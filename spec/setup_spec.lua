describe('lean.setup', function()
  it('Does not crash when loaded twice', function()
    require('lean').setup {}
    require('lean').setup {}
  end)
end)
