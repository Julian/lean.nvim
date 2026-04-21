---@brief [[
--- Tests for <img> tag rendering via the Kitty graphics protocol.
---@brief ]]

describe('tui.image', function()
  local img = require 'tui.image'

  -- A tiny 1x1 red PNG (67 bytes).
  local RED_PIXEL_B64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwADhQGAWjR9awAAAABJRU5ErkJggg==' -- luacheck: no max line length
  local RED_PIXEL_SRC = 'data:image/png;base64,' .. RED_PIXEL_B64

  it('decodes a PNG data URI', function()
    local decoded = img.decode(RED_PIXEL_SRC)
    assert.is_not_nil(decoded)
    assert.is_truthy(decoded.data)
  end)

  it('extracts dimensions from a PNG header', function()
    local decoded = img.decode(RED_PIXEL_SRC)
    assert.is_not_nil(decoded)
    assert.are.equal(1, decoded.width)
    assert.are.equal(1, decoded.height)
  end)

  it('rejects remote URLs', function()
    local decoded, reason = img.decode('https://example.com/image.png')
    assert.is_nil(decoded)
    assert.is_truthy(reason:find('remote URLs not supported'))
  end)

  it('rejects unsupported src formats', function()
    local decoded, reason = img.decode('file:///path/to/image.png')
    assert.is_nil(decoded)
    assert.is_truthy(reason:find('unsupported src format'))
  end)

  it('returns an error for invalid base64 payload', function()
    local decoded, reason = img.decode('data:image/png;base64,!!INVALID!!')
    assert.is_nil(decoded)
    assert.is_truthy(reason:find('invalid base64'))
  end)

  it('caches decoded images by src', function()
    local d1 = img.decode(RED_PIXEL_SRC)
    local d2 = img.decode(RED_PIXEL_SRC)
    assert.are.equal(d1, d2) -- same table reference
  end)

  it('survives cache eviction without crashing', function()
    for i = 1, 35 do
      local fake_data = vim.base64.encode(string.rep(string.char(i), 4))
      local decoded = img.decode('data:image/png;base64,' .. fake_data)
      assert.is_not_nil(decoded)
    end
  end)
end)

describe('html.Tag.img', function()
  local Tag = require('tui.html').Tag

  -- A tiny 1x1 red PNG (67 bytes).
  local RED_PIXEL_B64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwADhQGAWjR9awAAAABJRU5ErkJggg==' -- luacheck: no max line length
  local RED_PIXEL_SRC = 'data:image/png;base64,' .. RED_PIXEL_B64

  it('creates an element with an overlay for a data URI', function()
    local element = Tag.img({}, { src = RED_PIXEL_SRC })
    assert.is_not_nil(element.overlay)
    assert.are.equal(100, element.overlay.format)
    assert.is_truthy(element.overlay.data)
  end)

  it('uses intrinsic dimensions from the image', function()
    local element = Tag.img({}, { src = RED_PIXEL_SRC })
    assert.is_not_nil(element.overlay)
    assert.are.equal(1, element.overlay.width)
    assert.are.equal(1, element.overlay.height)
  end)

  it('prefers HTML attributes over intrinsic dimensions', function()
    local element = Tag.img({}, { src = RED_PIXEL_SRC, width = '50', height = '30' })
    assert.is_not_nil(element.overlay)
    assert.are.equal(50, element.overlay.width)
    assert.are.equal(30, element.overlay.height)
  end)

  it('reserves placeholder lines matching image height', function()
    local kitty = require 'kitty'
    local element = Tag.img({}, { src = RED_PIXEL_SRC, width = '10', height = '100' })
    local expected_rows = kitty.rows_for_height(100)
    local newlines = select(2, element.text:gsub('\n', '\n'))
    assert.are.equal(expected_rows - 1, newlines)
  end)

  it('shows fallback for missing src', function()
    local element = Tag.img({}, {})
    assert.is_nil(element.overlay)
    assert.is_truthy(element.text:find('no src'))
  end)
end)

describe('img dispatch', function()
  it('routes img elements through Tag.img', function()
    local Html = require 'proofwidgets.html'

    local RED_PIXEL_B64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwADhQGAWjR9awAAAABJRU5ErkJggg==' -- luacheck: no max line length
    local html_element = {
      element = {
        'img',
        { { 'src', 'data:image/png;base64,' .. RED_PIXEL_B64 } },
        {},
      },
    }

    local ctx = {
      subsession = function() end,
      rpc_call = function() end,
    }
    local element = Html(html_element, ctx)
    assert.is_not_nil(element)
    assert.is_not_nil(element.overlay)
  end)
end)
