---@mod tui.codicons Codicons in the terminal
---
---@brief [[
--- Renders VS Code's codicons (https://microsoft.github.io/vscode-codicons/).
---
--- Icons are lazily downloaded — one tiny SVG apiece, the first time
--- something asks for them — into Neovim's cache directory, then rasterized
--- via `tui.svg` and displayed with kitty graphics.
---
--- When graphics (or libresvg) are unavailable, falls back to rendering the
--- icon's Nerd Font glyph if the user has indicated they use one by setting
--- `vim.g.have_nerd_font`, as Nerd Fonts embed the full codicon set at its
--- original codepoints.
---@brief ]]

local image = require 'tui.image'
local kitty = require 'kitty'
local svg = require 'tui.svg'

local Element = require('lean.tui').Element
local log = require 'lean.log'

local codicons = {}

---The version of vscode-codicons we download icons from.
local REF = 'v0.0.45'

---Where we download icons from. Exposed (only) for use in tests.
codicons.base_url = ('https://raw.githubusercontent.com/microsoft/vscode-codicons/%s/'):format(REF)

---Where downloaded icons live. Exposed (only) for use in tests.
codicons.cache_dir = vim.fs.joinpath(vim.fn.stdpath 'cache', 'lean.nvim', 'codicons', REF)

---Repository-relative paths for the files we download.
---@param filename string a filename within our cache directory
---@return string subpath
local function subpath_of(filename)
  if filename == 'mapping.json' then
    return 'src/template/mapping.json'
  end
  return 'src/icons/' .. filename
end

---Files which already failed to download; we don't retry until next session.
---@type table<string, true>
local failed = {}

---Callbacks awaiting an in-flight download, keyed by filename.
---@type table<string, fun()[]>
local in_flight = {}

---@param filename string
---@return string path
local function cache_path(filename)
  return vim.fs.joinpath(codicons.cache_dir, filename)
end

---@param filename string
---@return string? contents nil if the file isn't cached
local function read_cached(filename)
  local file = io.open(cache_path(filename), 'r')
  if not file then
    return nil
  end
  local contents = file:read '*a'
  file:close()
  return contents
end

---Lazily download a file from the codicons repository into our cache.
---@param filename string
---@param on_done fun() called (on the main loop) once the download settles
local function fetch(filename, on_done)
  if in_flight[filename] then
    table.insert(in_flight[filename], on_done)
    return
  end
  in_flight[filename] = { on_done }

  local function settle(err)
    local callbacks = in_flight[filename]
    in_flight[filename] = nil
    if err then
      failed[filename] = true
      log:warning { message = 'Failed to download a codicon', filename = filename, err = err }
    end
    for _, callback in ipairs(callbacks) do
      callback()
    end
  end

  local path = cache_path(filename)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  local url = codicons.base_url .. subpath_of(filename)
  local partial = path .. '.partial'
  local ok, err = pcall(
    vim.system,
    { 'curl', '--fail', '--silent', '--show-error', '--location', url, '--output', partial },
    {},
    vim.schedule_wrap(function(out)
      if out.code == 0 then
        vim.uv.fs_rename(partial, path)
        settle()
      else
        settle(out.stderr)
      end
    end)
  )
  if not ok then -- e.g. no curl executable
    vim.schedule(function()
      settle(err)
    end)
  end
end

---Codicon name → codepoint, parsed once from the downloaded mapping.
---@type table<string, integer>?
local codepoints

---@return table<string, integer>? codepoints nil if the mapping isn't cached
local function load_codepoints()
  if codepoints then
    return codepoints
  end
  local contents = read_cached 'mapping.json'
  if not contents then
    return nil
  end
  local ok, mapping = pcall(vim.json.decode, contents)
  if not ok then
    log:error { message = 'Invalid codicon mapping', err = mapping }
    failed['mapping.json'] = true
    return nil
  end
  codepoints = {}
  for codepoint, names in pairs(mapping) do
    for _, name in ipairs(names) do
      codepoints[name] = tonumber(codepoint)
    end
  end
  return codepoints
end

---Whether we can rasterize icons and display them with kitty graphics.
---@return boolean
local function raster_available()
  return require 'lean.config'().graphics.enabled ~= false and kitty.available() and svg.available()
end

---Rasterized icons we've already built, keyed by name, color and size.
---@type table<string, ImageOverlay>
local overlays = {}

---An element displaying the icon via kitty graphics.
---@param name string
---@param hlgroup string highlight group whose foreground colors the icon
---@return Element? element nil if the icon isn't cached or fails to render
local function raster(name, hlgroup)
  local cell = kitty.cell_size()
  local hl = vim.api.nvim_get_hl(0, { name = hlgroup, link = false })
  local color = ('#%06x'):format(hl.fg or 0xcccccc)

  local key = ('codicon:%s:%s:%d'):format(name, color, cell.height)
  local overlay = overlays[key]
  if not overlay then
    local source = read_cached(name .. '.svg')
    if not source then
      return nil
    end
    -- Codicon SVGs are uniformly 16x16 with `fill="currentColor"` on the
    -- root; scale them to one cell and bake in the highlight's color.
    source = source
      :gsub('width="16"', ('width="%d"'):format(cell.height), 1)
      :gsub('height="16"', ('height="%d"'):format(cell.height), 1)
      :gsub('fill="currentColor"', ('fill="%s"'):format(color), 1)
    local ok, pixels, width, height = pcall(svg.rasterize, source)
    if not ok then
      log:error { message = 'Failed to rasterize a codicon', name = name, err = pixels }
      return nil
    end
    overlay = image.from_pixels(key, pixels, width, height)
    overlays[key] = overlay
  end

  local columns = math.ceil(overlay.width / cell.width)
  return Element:new { text = (' '):rep(columns), overlay = overlay }
end

---An element displaying the icon's Nerd Font glyph.
---@param name string
---@return Element? element nil if the mapping isn't cached or has no glyph
local function glyph(name)
  local cps = load_codepoints()
  local codepoint = cps and cps[name]
  if not codepoint then
    return nil
  end
  return Element:new { text = vim.fn.nr2char(codepoint, 1) }
end

---@class CodiconOpts
---@field fallback? Element shown while downloading or if no icon can render
---@field hlgroup? string colors rasterized icons (default `widgetLink`)

---An element rendering the named codicon as faithfully as we know how.
---
---Prefers a rasterized icon displayed with kitty graphics, then a Nerd Font
---glyph. Anything missing from the local cache is downloaded asynchronously,
---with `opts.fallback` (or the best already-cached rendering) shown until it
---arrives.
---@param name string a codicon name, e.g. one of those at https://microsoft.github.io/vscode-codicons/dist/codicon.html
---@param opts? CodiconOpts
---@return Element? element nil if no icon can be rendered at all
function codicons.element(name, opts)
  opts = opts or {}
  local want_raster = raster_available()
  -- nonzero, since the flag may come from vimscript where booleans are numbers
  local want_glyph = vim.g.have_nerd_font and vim.g.have_nerd_font ~= 0

  if not want_raster and not want_glyph then
    return nil
  end

  ---The best element we can build from what's cached right now.
  ---@return Element?
  local function resolve()
    if want_raster then
      local element = raster(name, opts.hlgroup or 'widgetLink')
      if element then
        return element
      end
    end
    if want_glyph then
      return glyph(name)
    end
  end

  local missing = {} ---@type string[]
  local icon_file = name .. '.svg'
  if want_raster and not failed[icon_file] and not vim.uv.fs_stat(cache_path(icon_file)) then
    table.insert(missing, icon_file)
  end
  if
    want_glyph
    and not codepoints
    and not failed['mapping.json']
    and not vim.uv.fs_stat(cache_path 'mapping.json')
  then
    table.insert(missing, 'mapping.json')
  end

  if #missing == 0 then
    return resolve()
  end

  local interim = resolve() or opts.fallback
  return Element:new {
    name = 'codicon:' .. name,
    children = interim and { interim } or nil,
    __async_init = function(resolved)
      local remaining = #missing
      for _, filename in ipairs(missing) do
        fetch(filename, function()
          remaining = remaining - 1
          if remaining == 0 then
            resolved(resolve() or opts.fallback or Element.EMPTY)
          end
        end)
      end
    end,
  }
end

return codicons
