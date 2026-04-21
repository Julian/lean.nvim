---SVG rasterization via resvg FFI and HTML tree serialization.
local ffi = require 'ffi'

local svg = {}

pcall(
  ffi.cdef,
  [[
  typedef struct resvg_options resvg_options;
  typedef struct resvg_render_tree resvg_render_tree;

  typedef struct { float a, b, c, d, e, f; } resvg_transform;
  typedef struct { float width, height; } resvg_size;

  resvg_options *resvg_options_create(void);
  void resvg_options_destroy(resvg_options *opt);

  int32_t resvg_parse_tree_from_data(
    const char *data, size_t len,
    const resvg_options *opt,
    resvg_render_tree **tree
  );

  resvg_size resvg_get_image_size(const resvg_render_tree *tree);
  resvg_transform resvg_transform_identity(void);

  void resvg_render(
    const resvg_render_tree *tree,
    resvg_transform transform,
    uint32_t width, uint32_t height,
    char *pixmap
  );

  void resvg_tree_destroy(resvg_render_tree *tree);
]]
)

---@type ffi.namespace*?
local libresvg

---Try to load libresvg. Returns true if available.
function svg.available()
  if libresvg then
    return true
  end
  local ok, lib = pcall(ffi.load, 'resvg')
  if ok then
    libresvg = lib
    return true
  end
  return false
end

-- Maximum number of pixels we're willing to allocate (16 megapixels).
local MAX_PIXELS = 16 * 1024 * 1024

---Render an SVG string to RGBA pixel data.
---@param data string SVG source
---@return ffi.cdata* pixels, integer width, integer height
function svg.rasterize(data)
  assert(libresvg, 'libresvg not loaded')

  local opts = libresvg.resvg_options_create()
  local tree_ptr = ffi.new 'resvg_render_tree*[1]'

  local rc = libresvg.resvg_parse_tree_from_data(data, #data, opts, tree_ptr)
  libresvg.resvg_options_destroy(opts)
  assert(rc == 0, 'resvg_parse_tree_from_data failed: ' .. rc)

  -- Guard against leaking the tree if anything below errors.
  local tree = ffi.gc(tree_ptr[0], libresvg.resvg_tree_destroy)

  local size = libresvg.resvg_get_image_size(tree)
  local w = math.max(1, math.ceil(size.width))
  local h = math.max(1, math.ceil(size.height))
  assert(w * h <= MAX_PIXELS, 'SVG too large: ' .. w .. 'x' .. h)

  local buf = ffi.new('char[?]', w * h * 4)

  local tf = libresvg.resvg_transform_identity()
  libresvg.resvg_render(tree, tf, w, h, buf)

  -- Prevent double-free: detach the GC destructor and destroy manually.
  ffi.gc(tree, nil)
  libresvg.resvg_tree_destroy(tree)

  return buf, w, h
end

local xml_escapes = {
  ['&'] = '&amp;',
  ['<'] = '&lt;',
  ['>'] = '&gt;',
  ['"'] = '&quot;',
}

---Serialize an Html element tree back to an SVG string.
---
---The `value` is a raw HtmlElement value: `{ tag, attrs, children }`.
---@param value { [1]: string, [2]: [string, any][], [3]: table[] }
---@return string
function svg.serialize(value)
  local parts = {}

  local function walk(node)
    if node.text then
      parts[#parts + 1] = node.text:gsub('[&<>]', xml_escapes)
      return
    end

    if not node.element then
      return
    end

    local tag, attrs, children = unpack(node.element)
    parts[#parts + 1] = '<'
    parts[#parts + 1] = tag

    for _, attr in ipairs(attrs) do
      parts[#parts + 1] = ' '
      parts[#parts + 1] = attr[1]
      parts[#parts + 1] = '="'
      parts[#parts + 1] = tostring(attr[2]):gsub('[&<>"]', xml_escapes)
      parts[#parts + 1] = '"'
    end

    if #children == 0 then
      parts[#parts + 1] = '/>'
    else
      parts[#parts + 1] = '>'
      for _, child in ipairs(children) do
        walk(child)
      end
      parts[#parts + 1] = '</'
      parts[#parts + 1] = tag
      parts[#parts + 1] = '>'
    end
  end

  walk { element = value }
  return table.concat(parts)
end

return svg
