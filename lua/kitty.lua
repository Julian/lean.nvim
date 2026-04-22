---Kitty graphics protocol support: detection, image transmission, and placement.
local ffi = require 'ffi'

local kitty = {}

-- Protocol detection ---------------------------------------------------------

local graphics_supported = false

---Check well-known environment variables for terminals with Kitty graphics.
---This provides synchronous detection without requiring APC response support.
local function detect_from_env()
  -- KITTY_WINDOW_ID is set by Kitty itself.
  if vim.env.KITTY_WINDOW_ID then
    return true
  end
  -- WezTerm, Ghostty, and others set TERM or TERM_PROGRAM.
  local term = vim.env.TERM or ''
  local term_program = vim.env.TERM_PROGRAM or ''
  if term:find('kitty', 1, true) or term_program == 'WezTerm' or term_program == 'ghostty' then
    return true
  end
  return false
end

local QUERY_ID = 99999

---Send a Kitty graphics protocol query to probe for support.
---The terminal responds with an APC sequence if it supports the protocol.
---Requires Neovim to forward APC responses via TermResponse (recent feature).
---@param on_detected? fun() callback when support is confirmed
local function probe(on_detected)
  vim.api.nvim_create_autocmd('TermResponse', {
    group = vim.api.nvim_create_augroup('LeanKittyDetect', { clear = true }),
    callback = function(ev)
      local data = ev.data
      if type(data) ~= 'table' then
        return
      end
      local seq = data.sequence or data[1] or ''
      if seq:find('i=' .. QUERY_ID, 1, true) and seq:find('OK', 1, true) then
        graphics_supported = true
        if on_detected then
          on_detected()
        end
        return true -- delete this autocmd
      end
    end,
  })
  -- Query: transmit a 1x1 transparent pixel with a=q (query).
  vim.api.nvim_chan_send(2, string.format('\x1b_Gi=%d,s=1,v=1,a=q,t=d,f=24;AAAA\x1b\\', QUERY_ID))
end

---Callbacks registered to fire when graphics support is confirmed.
---@type fun()[]
local on_available_callbacks = {}

local function notify_available()
  for _, cb in ipairs(on_available_callbacks) do
    cb()
  end
  on_available_callbacks = {}
end

---Register a callback to fire when Kitty graphics becomes available.
---If already available, fires immediately.
---@param callback fun()
function kitty.on_available(callback)
  if graphics_supported then
    callback()
  else
    on_available_callbacks[#on_available_callbacks + 1] = callback
  end
end

-- Detect synchronously from env vars, then also send a probe which can
-- upgrade detection for terminals we don't recognize by name.
graphics_supported = detect_from_env()
if graphics_supported then
  notify_available()
elseif #vim.api.nvim_list_uis() > 0 then
  probe(notify_available)
else
  vim.api.nvim_create_autocmd('UIEnter', {
    once = true,
    callback = function()
      if not graphics_supported then
        graphics_supported = detect_from_env()
        if graphics_supported then
          notify_available()
        else
          probe(notify_available)
        end
      end
    end,
  })
end

---Check if the terminal supports the Kitty graphics protocol.
function kitty.available()
  return graphics_supported
end

-- Cell size detection --------------------------------------------------------

pcall(
  ffi.cdef,
  [[
  struct kitty_winsize {
    unsigned short ws_row;
    unsigned short ws_col;
    unsigned short ws_xpixel;
    unsigned short ws_ypixel;
  };
  int ioctl(int fd, unsigned long request, ...);
]]
)

local cell_size_cache

-- TIOCGWINSZ: macOS = 0x40087468, Linux = 0x5413.
local TIOCGWINSZ = jit.os == 'Linux' and 0x5413 or 0x40087468

---Query the terminal for cell pixel dimensions.
---@return { width: integer, height: integer }
function kitty.cell_size()
  if cell_size_cache then
    return cell_size_cache
  end

  local ok, ws = pcall(ffi.new, 'struct kitty_winsize')
  if ok then
    local rc = ffi.C.ioctl(2, TIOCGWINSZ, ws)
    if rc == 0 and ws.ws_xpixel > 0 and ws.ws_ypixel > 0 then
      cell_size_cache = {
        width = math.floor(ws.ws_xpixel / ws.ws_col),
        height = math.floor(ws.ws_ypixel / ws.ws_row),
      }
      return cell_size_cache
    end
  end

  cell_size_cache = { width = 8, height = 16 }
  return cell_size_cache
end

vim.api.nvim_create_autocmd('VimResized', {
  group = vim.api.nvim_create_augroup('LeanKittyCellSize', { clear = true }),
  callback = function()
    cell_size_cache = nil
  end,
})

---Compute how many terminal rows an image of the given pixel height occupies.
---@param pixel_height integer
---@return integer
function kitty.rows_for_height(pixel_height)
  return math.max(1, math.ceil(pixel_height / kitty.cell_size().height))
end

-- Image transmission and placement -------------------------------------------

local CHANNEL = 2
local MAX_IMAGE_ID = 0xFFFFFFFF
local image_id_counter = 0

---Transmit image data as a Kitty image (stored, not displayed).
---@param data string image payload (raw RGBA bytes for f=32, encoded PNG/JPEG for f=100)
---@param width integer source width in pixels
---@param height integer source height in pixels
---@param format? integer Kitty format: 32 (raw RGBA, default) or 100 (auto-detect encoded)
---@return integer id
local function transmit(data, width, height, format)
  format = format or 32
  image_id_counter = image_id_counter % MAX_IMAGE_ID + 1
  local id = image_id_counter

  local b64 = vim.base64.encode(data)

  local CHUNK = 4096
  for i = 1, #b64, CHUNK do
    local chunk = b64:sub(i, i + CHUNK - 1)
    local more = (i + CHUNK - 1 < #b64) and 1 or 0
    local header
    if i == 1 then
      if format == 100 then
        header = string.format('\x1b_Ga=t,i=%d,f=100,m=%d;', id, more)
      else
        header = string.format('\x1b_Ga=t,i=%d,f=32,s=%d,v=%d,m=%d;', id, width, height, more)
      end
    else
      header = string.format('\x1b_Gm=%d;', more)
    end
    vim.api.nvim_chan_send(CHANNEL, header .. chunk .. '\x1b\\')
  end

  return id
end

---Delete a Kitty image by ID (removes image data and all placements).
---@param id integer
local function delete(id)
  vim.api.nvim_chan_send(CHANNEL, string.format('\x1b_Ga=d,d=i,i=%d;\x1b\\', id))
end

---Place an already-transmitted image at a screen position with clipping.
---Uses a fixed placement id so that re-placing replaces the old placement
---rather than accumulating duplicates (avoids needing delete_placements).
local function place(id, src_y, src_w, src_h, screen_row, screen_col, display_rows, display_cols)
  vim.api.nvim_chan_send(
    CHANNEL,
    string.format(
      '\x1b7\x1b[%d;%dH\x1b_Ga=p,i=%d,p=1,x=0,y=%d,w=%d,h=%d,r=%d,c=%d;\x1b\\\x1b8',
      screen_row,
      screen_col,
      id,
      src_y,
      src_w,
      src_h,
      display_rows,
      display_cols
    )
  )
end

-- ImageSet: manages a group of images for a single BufRenderer ---------------

---@class ImageSet
---@field private _images { data: string, width: integer, height: integer, format: integer, kitty_id: integer? }[]
local ImageSet = {}
ImageSet.__index = ImageSet

function ImageSet:new()
  return setmetatable({ _images = {} }, self)
end

---Register an image for display. Returns a handle.
---@param data string image payload (raw RGBA for f=32, encoded for f=100)
---@param width integer
---@param height integer
---@param format? integer Kitty format (default 32)
---@return integer handle
function ImageSet:add(data, width, height, format)
  local handle = #self._images + 1
  self._images[handle] = { data = data, width = width, height = height, format = format or 32 }
  return handle
end

---Transmit all images that haven't been transmitted yet.
function ImageSet:ensure_transmitted()
  for _, img in ipairs(self._images) do
    if not img.kitty_id then
      img.kitty_id = transmit(img.data, img.width, img.height, img.format)
    end
  end
end

---Return the number of images in the set.
---@return integer
function ImageSet:count()
  return #self._images
end

---Delete all Kitty images and clear the set.
function ImageSet:clear()
  for _, img in ipairs(self._images) do
    if img.kitty_id then
      delete(img.kitty_id)
    end
  end
  self._images = {}
end

---Place all images within a window, handling clipping.
---Uses a fixed placement id per image so re-placing replaces automatically.
---@param win any Window object
---@param positions table<integer, { row: integer, col: integer }> handle → buffer position (0-indexed)
function ImageSet:place_all(win, positions)
  self:ensure_transmitted()

  local winid = win.id or win
  local winpos = vim.api.nvim_win_get_position(winid)
  local topline = vim.fn.getwininfo(winid)[1].topline - 1 -- 0-indexed
  local win_height = vim.api.nvim_win_get_height(winid)
  local cell = kitty.cell_size()

  for handle, pos in pairs(positions) do
    local img = self._images[handle]
    if img and img.kitty_id then
      local image_rows = kitty.rows_for_height(img.height)
      local visible_row = pos.row - topline

      if visible_row + image_rows > 0 and visible_row < win_height then
        local src_y = 0
        local src_h = img.height
        local place_row = visible_row

        if visible_row < 0 then
          local clipped_rows = -visible_row
          src_y = clipped_rows * cell.height
          src_h = src_h - src_y
          place_row = 0
        end

        local max_visible_h = (win_height - place_row) * cell.height
        if src_h > max_visible_h then
          src_h = max_visible_h
        end

        if src_h > 0 then
          local display_rows = math.max(1, math.ceil(src_h / cell.height))
          place(
            img.kitty_id,
            src_y,
            img.width,
            src_h,
            winpos[1] + place_row + 1,
            winpos[2] + pos.col + 1,
            display_rows,
            math.ceil(img.width / cell.width)
          )
        end
      end
    end
  end
end

kitty.ImageSet = ImageSet

return kitty
