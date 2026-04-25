---@mod tui.plot Terminal plots via kitty graphics
---
---@brief [[
--- Renders data as pixel plots displayed via the kitty graphics protocol.
--- Returns nil when kitty graphics are unavailable.
---@brief ]]

local ffi = require 'ffi'

local image = require 'tui.image'
local kitty = require 'kitty'

local Element = require('lean.tui').Element

local plot = {}

local plot_id = 0

-- Colors (RGBA).
local COLOR_AXIS = { 100, 100, 100, 255 }
local COLOR_GRID = { 60, 60, 60, 255 }
local COLOR_LINE = { 80, 180, 220, 255 }
local COLOR_POINT = { 100, 200, 240, 255 }

local PADDING = { left = 8, right = 8, top = 8, bottom = 8 }
local POINT_RADIUS = 2
local LINE_THICKNESS = 2
local Y_MARGIN = 0.1 -- 10% padding above and below data range

---Set a single pixel in an RGBA buffer (bounds-checked).
---@param buf ffi.cdata*
---@param w integer image width
---@param h integer image height
---@param x integer 0-indexed
---@param y integer 0-indexed
---@param r integer
---@param g integer
---@param b integer
---@param a integer
local function set_pixel(buf, w, h, x, y, r, g, b, a)
  if x < 0 or x >= w or y < 0 or y >= h then
    return
  end
  local offset = (y * w + x) * 4
  buf[offset] = r
  buf[offset + 1] = g
  buf[offset + 2] = b
  buf[offset + 3] = a
end

---Draw a thick line (multiple parallel Bresenham lines).
local function draw_line(buf, w, h, x0, y0, x1, y1, color, thickness)
  local r, g, b, a = color[1], color[2], color[3], color[4]
  local half = math.floor(thickness / 2)
  -- For each offset perpendicular to the line, draw a Bresenham line.
  -- Use both horizontal and vertical offsets for consistent thickness.
  for offset = -half, half - 1 + (thickness % 2) do
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    -- Offset perpendicular to the dominant axis.
    local ox, oy
    if dx >= dy then
      ox, oy = 0, offset
    else
      ox, oy = offset, 0
    end

    local lx0, ly0 = x0 + ox, y0 + oy
    local lx1, ly1 = x1 + ox, y1 + oy
    local ldx = math.abs(lx1 - lx0)
    local ldy = -math.abs(ly1 - ly0)
    local sx = lx0 < lx1 and 1 or -1
    local sy = ly0 < ly1 and 1 or -1
    local err = ldx + ldy

    while true do
      set_pixel(buf, w, h, lx0, ly0, r, g, b, a)
      if lx0 == lx1 and ly0 == ly1 then
        break
      end
      local e2 = 2 * err
      if e2 >= ldy then
        err = err + ldy
        lx0 = lx0 + sx
      end
      if e2 <= ldx then
        err = err + ldx
        ly0 = ly0 + sy
      end
    end
  end
end

---Draw a filled circle.
local function fill_circle(buf, w, h, cx, cy, radius, color)
  local r, g, b, a = color[1], color[2], color[3], color[4]
  for dy = -radius, radius do
    for dx = -radius, radius do
      if dx * dx + dy * dy <= radius * radius then
        set_pixel(buf, w, h, cx + dx, cy + dy, r, g, b, a)
      end
    end
  end
end

---Draw a horizontal line.
local function hline(buf, w, h, x0, x1, y, color)
  local r, g, b, a = color[1], color[2], color[3], color[4]
  for x = x0, x1 do
    set_pixel(buf, w, h, x, y, r, g, b, a)
  end
end

---Draw a vertical line.
local function vline(buf, w, h, x, y0, y1, color)
  local r, g, b, a = color[1], color[2], color[3], color[4]
  for y = y0, y1 do
    set_pixel(buf, w, h, x, y, r, g, b, a)
  end
end

---Draw a dashed vertical line (alternating 3px on, 3px off).
local function dashed_vline(buf, w, h, x, y0, y1, color)
  local r, g, b, a = color[1], color[2], color[3], color[4]
  for y = y0, y1 do
    if (y - y0) % 6 < 3 then
      set_pixel(buf, w, h, x, y, r, g, b, a)
    end
  end
end

---Draw a dashed horizontal line.
local function dashed_hline(buf, w, h, x0, x1, y, color)
  local r, g, b, a = color[1], color[2], color[3], color[4]
  for x = x0, x1 do
    if (x - x0) % 6 < 3 then
      set_pixel(buf, w, h, x, y, r, g, b, a)
    end
  end
end

---Map a data value to pixel coordinates within the plot area.
---@param val number the data value
---@param min_val number data minimum
---@param max_val number data maximum
---@param px_min integer pixel minimum (plot area start)
---@param px_max integer pixel maximum (plot area end)
---@return integer pixel coordinate
local function map_value(val, min_val, max_val, px_min, px_max)
  if max_val == min_val then
    return math.floor((px_min + px_max) / 2)
  end
  local t = (val - min_val) / (max_val - min_val)
  return math.floor(px_min + t * (px_max - px_min) + 0.5)
end

---Compute a default pixel width based on window columns and cell size.
---@param columns? integer window width in columns
---@return integer pixels
local function default_width(columns)
  columns = columns or 60
  return columns * kitty.cell_size().width
end

---Pick evenly-spaced "nice" y-axis gridline values within a range.
---@param y_min number
---@param y_max number
---@return number[]
local function y_gridlines(y_min, y_max)
  local span = y_max - y_min
  if span <= 0 then
    return {}
  end
  -- Target ~3-4 gridlines.
  local rough_step = span / 4
  -- Round to a "nice" number (1, 2, 5 × 10^n).
  local mag = 10 ^ math.floor(math.log10(rough_step))
  local nice = rough_step / mag
  local step
  if nice <= 1.5 then
    step = mag
  elseif nice <= 3.5 then
    step = 2 * mag
  else
    step = 5 * mag
  end
  local lines = {}
  local v = math.ceil(y_min / step) * step
  while v < y_max do
    if v > y_min then
      table.insert(lines, v)
    end
    v = v + step
  end
  return lines
end

---Render a scatter/line plot as an Element with a kitty graphics overlay.
---
---Data is an array of y-values; x is implied as the array index.
---Returns nil if kitty graphics are unavailable.
---@param data number[]
---@param opts? { width?: integer, height?: integer, columns?: integer, x_markers?: { position: number, label: string }[] }
---@return Element?
function plot.scatter(data, opts)
  if not kitty.available() or #data < 2 then
    return nil
  end

  opts = opts or {}
  local w = opts.width or default_width(opts.columns)
  local h = opts.height or 120

  -- Compute data bounds with margin.
  local data_min, data_max = math.huge, -math.huge
  for _, v in ipairs(data) do
    if v < data_min then
      data_min = v
    end
    if v > data_max then
      data_max = v
    end
  end
  local margin = (data_max - data_min) * Y_MARGIN
  if margin == 0 then
    margin = math.abs(data_min) * 0.1
    if margin == 0 then
      margin = 1
    end
  end
  local y_min = data_min - margin
  local y_max = data_max + margin

  -- Plot area in pixel coordinates.
  local plot_left = PADDING.left
  local plot_right = w - PADDING.right - 1
  local plot_top = PADDING.top
  local plot_bottom = h - PADDING.bottom - 1

  -- Allocate RGBA buffer (initialized to 0 = transparent black).
  local buf = ffi.new('char[?]', w * h * 4)

  -- Draw axes.
  hline(buf, w, h, plot_left, plot_right, plot_bottom, COLOR_AXIS)
  vline(buf, w, h, plot_left, plot_top, plot_bottom, COLOR_AXIS)

  -- Draw horizontal y-axis gridlines at nice intervals.
  for _, yv in ipairs(y_gridlines(y_min, y_max)) do
    local py = map_value(yv, y_min, y_max, plot_bottom, plot_top)
    dashed_hline(buf, w, h, plot_left + 1, plot_right, py, COLOR_GRID)
  end

  -- Draw optional vertical gridlines at caller-specified x positions
  -- and collect their column positions for text labels below the image.
  local n = #data
  local label_columns = {}
  if opts.x_markers then
    for _, marker in ipairs(opts.x_markers) do
      local pos = marker.position or marker[1]
      local label = marker.label or marker[2]
      if pos >= 1 and pos <= n then
        local px = map_value(pos, 1, n, plot_left, plot_right)
        dashed_vline(buf, w, h, px, plot_top, plot_bottom - 1, COLOR_GRID)
        if label then
          local col = math.floor(px / kitty.cell_size().width)
          table.insert(label_columns, { col = col, text = label })
        end
      end
    end
  end

  -- Map data points to pixel coordinates.
  local points = {}
  for i, v in ipairs(data) do
    local px = map_value(i, 1, n, plot_left, plot_right)
    local py = map_value(v, y_min, y_max, plot_bottom, plot_top)
    points[i] = { px, py }
  end

  -- Connect points with lines.
  for i = 1, #points - 1 do
    draw_line(
      buf,
      w,
      h,
      points[i][1],
      points[i][2],
      points[i + 1][1],
      points[i + 1][2],
      COLOR_LINE,
      LINE_THICKNESS
    )
  end

  -- Draw data points on top, but only when sparse enough that
  -- the circles don't overlap into a jagged mess.
  local plot_width = plot_right - plot_left
  if plot_width / n >= POINT_RADIUS * 2 then
    for _, pt in ipairs(points) do
      fill_circle(buf, w, h, pt[1], pt[2], POINT_RADIUS, COLOR_POINT)
    end
  end

  -- Unique key per render — the data changes every refresh so caching
  -- across renders would return stale images.
  plot_id = plot_id + 1
  local overlay = image.from_pixels(('plot:%d'):format(plot_id), buf, w, h)
  local rows = kitty.rows_for_height(h)

  local img_element = Element:new {
    text = string.rep('\n', rows - 1),
    overlay = overlay,
  }

  -- Build column-aligned label text below the image.
  if #label_columns == 0 then
    return img_element
  end

  -- Sort by column position and build the label string with spacing.
  table.sort(label_columns, function(a, b)
    return a.col < b.col
  end)
  local parts = {}
  local cursor = 0
  for _, lbl in ipairs(label_columns) do
    -- Center the label on the gridline column.
    local start = math.max(cursor, lbl.col - math.floor(#lbl.text / 2))
    if start > cursor then
      table.insert(parts, string.rep(' ', start - cursor))
    end
    table.insert(parts, lbl.text)
    cursor = start + #lbl.text
  end

  return Element:concat({
    img_element,
    Element:new { text = table.concat(parts), hlgroups = { 'Comment' } },
  }, '\n')
end

-- Standard HDR histogram percentile markers with their 1/(1-p) x-values.
local PERCENTILE_MARKERS = {
  { pct = 50, x = 2, label = '50%' },
  { pct = 90, x = 10, label = '90%' },
  { pct = 99, x = 100, label = '99%' },
  { pct = 99.9, x = 1000, label = '99.9%' },
}

---Render an HDR-style percentile distribution plot.
---
---X-axis is log-scaled 1/(1-percentile), giving equal visual weight to
---each "nine" of precision.  Y-axis is linear latency.
---Uses the histogram's cumulative distribution (actual bucket boundaries)
---for the exact shape, avoiding sampling artifacts.
---Returns nil if kitty graphics are unavailable or the histogram is empty.
---@param histogram std.Histogram
---@param opts? { width?: integer, height?: integer, columns?: integer }
---@return Element?
function plot.percentile_distribution(histogram, opts)
  if not kitty.available() or histogram:count() == 0 then
    return nil
  end

  opts = opts or {}
  local w = opts.width or default_width(opts.columns)
  local h = opts.height or 120

  -- Use the histogram's own bucket boundaries for the exact distribution
  -- shape.  Skip p=100 (log10(inf)) and very low quantiles where
  -- log10(1/(1-q/100)) ≈ 0 adds no visual information.
  local dist = histogram:cumulative_distribution()
  local x_vals = {}
  local y_vals = {}
  local x_min, x_max = math.huge, -math.huge
  local y_min_data, y_max_data = math.huge, -math.huge
  local n_points = 0

  for _, bracket in ipairs(dist) do
    local q = bracket.quantile
    if q > 0 and q < 100 then
      local x = math.log10(1 / (1 - q / 100))
      n_points = n_points + 1
      x_vals[n_points] = x
      y_vals[n_points] = bracket.value
      if x < x_min then
        x_min = x
      end
      if x > x_max then
        x_max = x
      end
      if bracket.value < y_min_data then
        y_min_data = bracket.value
      end
      if bracket.value > y_max_data then
        y_max_data = bracket.value
      end
    end
  end

  if n_points < 2 then
    return nil
  end

  -- Y-axis margin.
  local margin = (y_max_data - y_min_data) * Y_MARGIN
  if margin == 0 then
    margin = math.abs(y_min_data) * 0.1
    if margin == 0 then
      margin = 1
    end
  end
  local y_min = y_min_data - margin
  local y_max = y_max_data + margin

  -- Plot area.
  local plot_left = PADDING.left
  local plot_right = w - PADDING.right - 1
  local plot_top = PADDING.top
  local plot_bottom = h - PADDING.bottom - 1

  local buf = ffi.new('char[?]', w * h * 4)

  -- Draw axes.
  hline(buf, w, h, plot_left, plot_right, plot_bottom, COLOR_AXIS)
  vline(buf, w, h, plot_left, plot_top, plot_bottom, COLOR_AXIS)

  -- Draw y-axis gridlines.
  for _, yv in ipairs(y_gridlines(y_min, y_max)) do
    local py = map_value(yv, y_min, y_max, plot_bottom, plot_top)
    dashed_hline(buf, w, h, plot_left + 1, plot_right, py, COLOR_GRID)
  end

  -- Draw vertical gridlines and collect label positions.
  local cell_w = kitty.cell_size().width
  local label_columns = {}
  for _, m in ipairs(PERCENTILE_MARKERS) do
    local mx = math.log10(m.x)
    if mx >= x_min and mx <= x_max then
      local px = map_value(mx, x_min, x_max, plot_left, plot_right)
      dashed_vline(buf, w, h, px, plot_top, plot_bottom - 1, COLOR_GRID)
      table.insert(label_columns, { col = math.floor(px / cell_w), text = m.label })
    end
  end

  -- Map and draw data points.
  local points = {}
  for i = 1, n_points do
    local px = map_value(x_vals[i], x_min, x_max, plot_left, plot_right)
    local py = map_value(y_vals[i], y_min, y_max, plot_bottom, plot_top)
    points[#points + 1] = { px, py }
  end

  for i = 1, #points - 1 do
    draw_line(
      buf,
      w,
      h,
      points[i][1],
      points[i][2],
      points[i + 1][1],
      points[i + 1][2],
      COLOR_LINE,
      LINE_THICKNESS
    )
  end

  plot_id = plot_id + 1
  local overlay = image.from_pixels(('plot:%d'):format(plot_id), buf, w, h)
  local rows = kitty.rows_for_height(h)

  local img_element = Element:new {
    text = string.rep('\n', rows - 1),
    overlay = overlay,
  }

  if #label_columns == 0 then
    return img_element
  end

  -- Build column-aligned labels, clamped to the available width.
  local max_col = math.floor(w / cell_w) - 1
  table.sort(label_columns, function(a, b)
    return a.col < b.col
  end)
  local parts = {}
  local cursor = 0
  for _, lbl in ipairs(label_columns) do
    local start = math.max(cursor, lbl.col - math.floor(#lbl.text / 2))
    if start + #lbl.text > max_col then
      break
    end
    if start > cursor then
      table.insert(parts, string.rep(' ', start - cursor))
    end
    table.insert(parts, lbl.text)
    cursor = start + #lbl.text
  end

  return Element:concat({
    img_element,
    Element:new { text = table.concat(parts), hlgroups = { 'Comment' } },
  }, '\n')
end

return plot
