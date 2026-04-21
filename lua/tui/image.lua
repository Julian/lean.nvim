---Image decoding, caching, and overlay creation for terminal graphics display.
local ffi = require 'ffi'

local image = {}

---@class ImageOverlay
---@field data string image payload
---@field width integer
---@field height integer
---@field format integer Kitty format: 32 (raw RGBA) or 100 (encoded PNG/JPEG)

---Extract width and height from a PNG header.
---@param data string raw PNG bytes
---@return integer? width, integer? height
local function png_dimensions(data)
  if #data < 24 then
    return nil
  end
  -- PNG signature: 0x89 P N G
  if data:sub(1, 4) ~= '\137PNG' then
    return nil
  end
  -- IHDR chunk: bytes 17-24 contain width and height as 4-byte big-endian.
  local function u32(offset)
    local a, b, c, d = data:byte(offset, offset + 3)
    return a * 16777216 + b * 65536 + c * 256 + d
  end
  return u32(17), u32(21)
end

---LRU cache of image overlays, keyed by caller-provided string.
local CACHE_SIZE = 64
local cache = {} ---@type table<string, ImageOverlay>
local cache_order = {} ---@type string[]

---Store an overlay in the cache, evicting the oldest entry if full.
---@param key string
---@param overlay ImageOverlay
local function cache_put(key, overlay)
  if cache[key] then
    return
  end
  cache[key] = overlay
  cache_order[#cache_order + 1] = key
  if #cache_order > CACHE_SIZE then
    cache[table.remove(cache_order, 1)] = nil
  end
end

---Decode an image from a data URI src attribute.
---
---Supports `data:<mime>;base64,<payload>` URIs. Returns an overlay
---with format=100 (Kitty auto-detects the encoded format).
---Results are cached by src string.
---
---@param src string the src attribute value
---@return { data: string, width: integer?, height: integer?, format: integer }? decoded
---@return string? reason on failure
function image.decode(src)
  if src:match('^https?://') then
    return nil, '[img: remote URLs not supported]'
  end

  local _, payload = src:match('^data:([^;]+);base64,(.+)$')
  if not payload then
    return nil, '[img: unsupported src format]'
  end

  local cached = cache[src]
  if cached then
    return cached
  end

  local ok, raw = pcall(vim.base64.decode, payload)
  if not ok then
    return nil, '[img: invalid base64 payload]'
  end
  local w, h = png_dimensions(raw)
  local overlay = { data = raw, width = w, height = h, format = 100 }
  cache_put(src, overlay)
  return overlay
end

---Create an overlay from raw RGBA pixel data (e.g. from rasterization).
---
---Converts the pixel buffer to a Lua string and caches the result
---by the provided key. Returns an overlay with format=32 (raw RGBA).
---
---@param key string cache key (e.g. the SVG source string)
---@param pixels ffi.cdata* RGBA pixel buffer
---@param width integer
---@param height integer
---@return ImageOverlay
function image.from_pixels(key, pixels, width, height)
  local cached = cache[key]
  if cached then
    return cached
  end
  local overlay = { data = ffi.string(pixels, width * height * 4), width = width, height = height, format = 32 }
  cache_put(key, overlay)
  return overlay
end

return image
